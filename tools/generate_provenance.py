#!/usr/bin/env python3
"""
SPDX-License-Identifier: Apache-2.0
HGL Provenance Manifest Generator

Generates provenance.json manifests for HGL releases.
Captures build metadata, input/output hashes, and policy evaluation results.

Usage:
    python generate_provenance.py --version 1.2-beta.1 --release-dir releases/HGL-v1.2-beta.1
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


class ProvenanceGenerator:
    """Generates provenance manifests for HGL releases"""
    
    def __init__(self, version: str, release_dir: Path, route: str = "standard"):
        self.version = version
        self.release_dir = release_dir
        self.route = route
        self.provenance = self._init_provenance()
    
    def _init_provenance(self) -> Dict:
        """Initialize provenance structure"""
        return {
            "artifact": f"HGL v{self.version}",
            "model": "claude-opus-4-20250514",
            "route": self.route,
            "build_utc": datetime.utcnow().isoformat() + "Z",
            "git": self._get_git_info(),
            "inputs": [],
            "outputs": [],
            "tools": [],
            "policy": {
                "version": "v1.2",
                "status": "unknown",
                "evaluation_utc": None,
                "gates": {}
            }
        }
    
    def _get_git_info(self) -> Dict:
        """Get Git repository information"""
        try:
            commit = subprocess.check_output(
                ["git", "rev-parse", "HEAD"],
                text=True
            ).strip()
            
            branch = subprocess.check_output(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                text=True
            ).strip()
            
            remote = subprocess.check_output(
                ["git", "config", "--get", "remote.origin.url"],
                text=True
            ).strip()
            
            # Get commit timestamp
            timestamp = subprocess.check_output(
                ["git", "show", "-s", "--format=%cI", "HEAD"],
                text=True
            ).strip()
            
            return {
                "commit": commit,
                "branch": branch,
                "remote": remote,
                "timestamp": timestamp
            }
        except subprocess.CalledProcessError as e:
            print(f"Warning: Failed to get Git info: {e}", file=sys.stderr)
            return {
                "commit": "unknown",
                "branch": "unknown",
                "remote": "unknown",
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
    
    def _compute_hash(self, file_path: Path) -> str:
        """Compute SHA256 hash of a file"""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)
        return sha256.hexdigest()
    
    def add_inputs(self, input_dir: Path):
        """Add input files to provenance"""
        if not input_dir.exists():
            print(f"Warning: Input directory not found: {input_dir}", file=sys.stderr)
            return
        
        for file_path in sorted(input_dir.rglob('*')):
            if file_path.is_file():
                rel_path = file_path.relative_to(input_dir)
                self.provenance["inputs"].append({
                    "path": str(rel_path),
                    "sha256": self._compute_hash(file_path),
                    "size_bytes": file_path.stat().st_size
                })
    
    def add_outputs(self):
        """Add output files from release directory"""
        if not self.release_dir.exists():
            print(f"Warning: Release directory not found: {self.release_dir}", file=sys.stderr)
            return
        
        for file_path in sorted(self.release_dir.rglob('*')):
            if file_path.is_file() and file_path.name != 'provenance.json':
                rel_path = file_path.relative_to(self.release_dir)
                self.provenance["outputs"].append({
                    "path": str(rel_path),
                    "sha256": self._compute_hash(file_path),
                    "size_bytes": file_path.stat().st_size
                })
    
    def add_tools(self, tools_dir: Path):
        """Add verification tools to provenance"""
        if not tools_dir.exists():
            print(f"Warning: Tools directory not found: {tools_dir}", file=sys.stderr)
            return
        
        tool_files = [
            "verify_and_eval.sh",
            "verify_and_eval.ps1",
            "generate_provenance.py",
            "generate-hashes.sh"
        ]
        
        for tool_name in tool_files:
            tool_path = tools_dir / tool_name
            if tool_path.exists():
                self.provenance["tools"].append({
                    "name": tool_name,
                    "sha256": self._compute_hash(tool_path),
                    "size_bytes": tool_path.stat().st_size
                })
    
    def evaluate_policy(self, policy_script: Optional[Path] = None):
        """Evaluate policy gates"""
        # If no policy script provided, look for it in standard locations
        if policy_script is None:
            candidates = [
                Path("tools/verify_and_eval.sh"),
                Path("verify_and_eval.sh")
            ]
            for candidate in candidates:
                if candidate.exists():
                    policy_script = candidate
                    break
        
        if policy_script is None or not policy_script.exists():
            print("Warning: Policy script not found, skipping evaluation", file=sys.stderr)
            self.provenance["policy"]["status"] = "skipped"
            return
        
        # Run policy evaluation
        try:
            result = subprocess.run(
                [str(policy_script), str(self.release_dir)],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            self.provenance["policy"]["evaluation_utc"] = datetime.utcnow().isoformat() + "Z"
            
            if result.returncode == 0:
                self.provenance["policy"]["status"] = "pass"
            else:
                self.provenance["policy"]["status"] = "fail"
                self.provenance["policy"]["exit_code"] = result.returncode
            
            # Parse policy output for gate results
            self._parse_policy_output(result.stdout)
            
        except subprocess.TimeoutExpired:
            self.provenance["policy"]["status"] = "timeout"
        except Exception as e:
            print(f"Warning: Policy evaluation failed: {e}", file=sys.stderr)
            self.provenance["policy"]["status"] = "error"
            self.provenance["policy"]["error"] = str(e)
    
    def _parse_policy_output(self, output: str):
        """Parse policy script output for gate results"""
        gates = {}
        current_gate = None
        
        for line in output.split('\n'):
            line = line.strip()
            
            # Look for gate headers
            if '===' in line and 'Gate' in line:
                # Extract gate name
                parts = line.split('===')
                if len(parts) >= 2:
                    gate_text = parts[1].strip()
                    if gate_text.startswith('Gate'):
                        current_gate = gate_text
                        gates[current_gate] = {"status": "unknown"}
            
            # Look for PASS/FAIL indicators
            elif current_gate and ('✓' in line or 'PASS' in line.upper()):
                gates[current_gate]["status"] = "pass"
            elif current_gate and ('✗' in line or 'FAIL' in line.upper()):
                gates[current_gate]["status"] = "fail"
        
        self.provenance["policy"]["gates"] = gates
    
    def generate(self) -> Dict:
        """Generate complete provenance manifest"""
        return self.provenance
    
    def save(self, output_path: Optional[Path] = None):
        """Save provenance manifest to file"""
        if output_path is None:
            output_path = self.release_dir / "provenance.json"
        
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(self.provenance, f, indent=2, sort_keys=True)
        
        print(f"✓ Provenance manifest saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate HGL provenance manifest",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate provenance for a release
  python generate_provenance.py --version 1.2-beta.1 --release-dir releases/HGL-v1.2-beta.1
  
  # Generate with custom input directory
  python generate_provenance.py --version 1.2-beta.1 --release-dir releases/HGL-v1.2-beta.1 --input-dir src/
  
  # Generate without policy evaluation
  python generate_provenance.py --version 1.2-beta.1 --release-dir releases/HGL-v1.2-beta.1 --no-policy
"""
    )
    
    parser.add_argument(
        '--version',
        required=True,
        help='Release version (e.g., 1.2-beta.1)'
    )
    
    parser.add_argument(
        '--release-dir',
        required=True,
        type=Path,
        help='Release directory containing output artifacts'
    )
    
    parser.add_argument(
        '--input-dir',
        type=Path,
        default=Path('src'),
        help='Input directory (default: src/)'
    )
    
    parser.add_argument(
        '--tools-dir',
        type=Path,
        default=Path('tools'),
        help='Tools directory (default: tools/)'
    )
    
    parser.add_argument(
        '--route',
        default='standard',
        choices=['standard', 'extended', 'constitutional'],
        help='Processing route used (default: standard)'
    )
    
    parser.add_argument(
        '--no-policy',
        action='store_true',
        help='Skip policy evaluation'
    )
    
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: <release-dir>/provenance.json)'
    )
    
    parser.add_argument(
        '--print',
        action='store_true',
        help='Print manifest to stdout instead of saving'
    )
    
    args = parser.parse_args()
    
    print(f"📝 Generating provenance manifest for HGL v{args.version}")
    print(f"   Release: {args.release_dir}")
    print(f"   Route:   {args.route}")
    print()
    
    # Initialize generator
    generator = ProvenanceGenerator(
        version=args.version,
        release_dir=args.release_dir,
        route=args.route
    )
    
    # Add inputs
    print("📥 Processing inputs...")
    generator.add_inputs(args.input_dir)
    print(f"   Found {len(generator.provenance['inputs'])} input files")
    
    # Add outputs
    print("📦 Processing outputs...")
    generator.add_outputs()
    print(f"   Found {len(generator.provenance['outputs'])} output files")
    
    # Add tools
    print("🔧 Processing tools...")
    generator.add_tools(args.tools_dir)
    print(f"   Found {len(generator.provenance['tools'])} tool files")
    
    # Evaluate policy
    if not args.no_policy:
        print("⚖️  Evaluating policy...")
        generator.evaluate_policy()
        print(f"   Policy status: {generator.provenance['policy']['status']}")
    else:
        print("⚠️  Skipping policy evaluation")
        generator.provenance['policy']['status'] = 'skipped'
    
    print()
    
    # Generate and save
    provenance = generator.generate()
    
    if args.print:
        print(json.dumps(provenance, indent=2, sort_keys=True))
    else:
        output_path = args.output if args.output else args.release_dir / "provenance.json"
        generator.save(output_path)
        
        # Print summary
        print(f"📊 Summary:")
        print(f"  Inputs:  {len(provenance['inputs'])} files")
        print(f"  Outputs: {len(provenance['outputs'])} files")
        print(f"  Tools:   {len(provenance.get('tools', []))} files")
        print(f"  Policy:  {provenance['policy']['status'].upper()}")


if __name__ == "__main__":
    main()
