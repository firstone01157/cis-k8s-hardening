#!/usr/bin/env python3
"""
harden_manifests.py - Robust Static Pod Manifest Hardening Tool

Purpose: Safely modify Kubernetes static pod manifests (/etc/kubernetes/manifests/)
using line-by-line parsing (NO external dependencies like PyYAML).

Features:
- No external dependencies (uses stdlib only)
- Smart deduplication: removes old flag instances before adding new ones
- Intelligent plugin merging: merges into comma-separated lists (no data loss)
- Preserves exact indentation and YAML structure
- Creates timestamped backups before modifying
- Validates YAML syntax (basic)
- Type-safe flag parsing and replacement

Usage:
    python3 harden_manifests.py \\
        --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \\
        --flag --anonymous-auth \\
        --value false \\
        --ensure present

Exit Codes:
    0 = Success (changed or no change needed)
    1 = Error (invalid args, file not found, parse error, etc.)
"""

import os
import sys
import argparse
import shutil
import re
from pathlib import Path
from datetime import datetime
from typing import List, Tuple, Optional


class ManifestHardener:
    """Safely modify Kubernetes static pod manifests using line-by-line parsing."""

    def __init__(self, manifest_path: str):
        """
        Initialize the hardener with a manifest file.

        Args:
            manifest_path: Full path to the YAML manifest file.

        Raises:
            FileNotFoundError: If manifest doesn't exist.
            ValueError: If manifest is not readable or empty.
        """
        self.manifest_path = Path(manifest_path)

        if not self.manifest_path.exists():
            raise FileNotFoundError(f"Manifest not found: {self.manifest_path}")

        if not self.manifest_path.is_file():
            raise ValueError(f"Not a file: {self.manifest_path}")

        self._original_lines = []
        self._lines = []
        self._command_section_indices = []
        self._load_manifest()

    def _load_manifest(self) -> None:
        """Load the manifest file and parse command section indices."""
        try:
            with open(self.manifest_path, 'r') as f:
                self._original_lines = f.readlines()
        except Exception as e:
            raise RuntimeError(f"Failed to read manifest: {e}")

        if not self._original_lines:
            raise ValueError(f"Manifest is empty: {self.manifest_path}")

        # Make a working copy
        self._lines = self._original_lines.copy()

        # Find the 'command:' section and its list items
        self._find_command_section()

    def _find_command_section(self) -> None:
        """
        DUMB & ROBUST PARSER: Find 'command:' section in Kubernetes manifest.
        
        Algorithm:
        1. Iterate through lines to find the string 'command:'
        2. Check for inline format (contains '[')
        3. For block format: look at immediately following non-empty lines
        4. IF the next non-empty line starts with '-', capture its indentation
        5. Collect all lines at THAT indentation starting with '-'
        6. Stop when hitting a line NOT starting with '-' at that indent
        
        Why this works: Don't try to be smart about structure.
        Just find command:, look at what comes next, use its indentation as truth.
        """
        command_line_index = -1
        command_list_indent = -1
        found_command = False
        
        for i, line in enumerate(self._lines):
            stripped = line.lstrip()
            current_indent = len(line) - len(stripped)
            
            # Skip empty lines and comments
            if not stripped or stripped.startswith('#'):
                continue
            
            # Step 1: Find 'command:' key (could be 'command:' or '- command:')
            if not found_command:
                # Check if this line contains the 'command:' key
                if 'command:' in stripped:
                    found_command = True
                    command_line_index = i
                    
                    # Check for inline format: command: ["arg1", "arg2"]
                    if '[' in stripped:
                        # Inline list - mark this line and return
                        self._command_section_indices = [i]
                        return
                    
                    # Block format found. Now look at the next non-empty lines
                    # for the first line starting with '- '
                    list_start_index = -1
                    for j in range(i + 1, len(self._lines)):
                        next_stripped = self._lines[j].lstrip()
                        
                        # Skip empty and comment lines
                        if not next_stripped or next_stripped.startswith('#'):
                            continue
                        
                        # Found a line starting with '-'?
                        if next_stripped.startswith('- '):
                            # THIS IS THE COMMAND LIST START!
                            next_indent = len(self._lines[j]) - len(next_stripped)
                            command_list_indent = next_indent
                            list_start_index = j
                            break
                        
                        # If we hit a different key-value (has ':' and NOT starting with '-'),
                        # then there's no command list - abort
                        if ':' in next_stripped and not next_stripped.startswith('- '):
                            break
                    
                    # If we found the list start, collect all items at that indentation
                    if command_list_indent >= 0:
                        # Start from the list start line and collect all '-' items
                        # at the exact same indentation
                        for j in range(list_start_index, len(self._lines)):
                            item_stripped = self._lines[j].lstrip()
                            item_indent = len(self._lines[j]) - len(item_stripped)
                            
                            # Skip empty and comments
                            if not item_stripped or item_stripped.startswith('#'):
                                continue
                            
                            # If this line is at the list indent AND starts with '-'
                            if item_indent == command_list_indent and item_stripped.startswith('- '):
                                self._command_section_indices.append(j)
                            # If we hit a line at this indent that does NOT start with '-',
                            # we've left the command section
                            elif item_indent == command_list_indent and not item_stripped.startswith('- '):
                                break
                            # If we hit a line at LOWER indent, we're definitely done
                            elif item_indent < command_list_indent:
                                break
                    
                    return
        
        # Validation: did we find a command section?
        if self._command_section_indices:
            return
        
        # Error: No command section found
        found_command_key = any('command:' in line for line in self._lines)
        
        if not found_command_key:
            raise ValueError(
                "No 'command:' key found in manifest. "
                "This manifest may not be a Kubernetes pod/deployment spec."
            )
        else:
            # Found 'command:' but couldn't find list items
            for i, line in enumerate(self._lines):
                if 'command:' in line:
                    start = max(0, i - 1)
                    end = min(len(self._lines), i + 10)
                    context_str = '\n'.join(
                        f"    {start + j + 1:3d}: {self._lines[start + j].rstrip()}" 
                        for j in range(end - start)
                    )
                    raise ValueError(
                        f"Found 'command:' key but no list items (lines starting with '- ') detected.\n"
                        f"Context around 'command:' (lines {start+1}-{end}):\n{context_str}"
                    )
            raise ValueError("Found 'command:' key but could not parse list items.")

    def _normalize_flag(self, flag: str) -> str:
        """
        Normalize flag name (ensure it starts with --).

        Args:
            flag: Flag name (e.g., 'anonymous-auth' or '--anonymous-auth').

        Returns:
            Normalized flag name (e.g., '--anonymous-auth').
        """
        if not flag.startswith('--'):
            flag = f'--{flag}'
        return flag

    def _strip_quotes(self, value: str) -> str:
        """
        Remove surrounding quotes from a value.

        Args:
            value: Value that may have quotes (e.g., '"false"', "'true'").

        Returns:
            Value without quotes.
        """
        if value and len(value) >= 2:
            if (value[0] == '"' and value[-1] == '"') or \
               (value[0] == "'" and value[-1] == "'"):
                return value[1:-1]
        return value

    def _parse_flag_from_line(self, line: str) -> Tuple[Optional[str], Optional[str]]:
        """
        Extract flag and value from a line in command list.

        Examples:
            '    - --anonymous-auth=false' -> ('--anonymous-auth', 'false')
            '    - --some-flag' -> ('--some-flag', None)
            '    - kube-apiserver' -> (None, None)

        Args:
            line: A line from the command list.

        Returns:
            Tuple of (flag, value) or (None, None) if not a flag.
        """
        # Remove leading spaces and '- '
        stripped = line.lstrip()
        if not stripped.startswith('- '):
            return (None, None)

        arg = stripped[2:].strip()

        # Check for '=' separator
        if '=' in arg:
            parts = arg.split('=', 1)
            flag = parts[0].strip()
            value = parts[1].strip()
            return (flag, value)
        else:
            # Flag without value
            return (arg, None)

    def _find_flag_in_command(self, flag: str) -> Optional[int]:
        """
        Find the line index of a flag in the command section.

        Args:
            flag: Normalized flag name (e.g., '--anonymous-auth').

        Returns:
            Line index if found, None otherwise.
        """
        for idx in self._command_section_indices:
            found_flag, _ = self._parse_flag_from_line(self._lines[idx])
            if found_flag == flag:
                return idx
        return None

    def _get_command_indent(self) -> str:
        """
        Get the indentation string used for command list items.

        Returns:
            Indentation string (e.g., '    ').
        """
        if not self._command_section_indices:
            return '    '  # Default to 4 spaces

        first_command_line = self._lines[self._command_section_indices[0]]
        stripped = first_command_line.lstrip()
        indent_len = len(first_command_line) - len(stripped)
        return first_command_line[:indent_len]

    def _format_flag_line(self, flag: str, value: Optional[str] = None) -> str:
        """
        Format a flag line with proper indentation.

        Args:
            flag: Flag name (e.g., '--anonymous-auth').
            value: Flag value or None.

        Returns:
            Formatted line with newline.
        """
        indent = self._get_command_indent()
        if value is not None:
            return f"{indent}- {flag}={value}\n"
        else:
            return f"{indent}- {flag}\n"

    def _create_backup(self) -> str:
        """
        Create a timestamped backup of the manifest.

        Returns:
            Path to the backup file.
        """
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_dir = self.manifest_path.parent / 'backups'

        try:
            backup_dir.mkdir(exist_ok=True)
        except Exception as e:
            raise RuntimeError(f"Failed to create backup directory: {e}")

        backup_path = backup_dir / f"{self.manifest_path.stem}_{timestamp}.yaml"

        try:
            shutil.copy2(self.manifest_path, backup_path)
            return str(backup_path)
        except Exception as e:
            raise RuntimeError(f"Failed to create backup: {e}")

    def _is_valid_yaml_basic(self, lines: List[str]) -> bool:
        """
        Basic YAML syntax validation (checks for obvious issues).

        Args:
            lines: List of lines from YAML file.

        Returns:
            True if looks valid, False otherwise.
        """
        # Check for unclosed quotes
        in_double = False
        in_single = False

        for line in lines:
            stripped = line.strip()
            if stripped.startswith('#'):
                continue

            for char in stripped:
                if char == '"' and not in_single:
                    in_double = not in_double
                elif char == "'" and not in_double:
                    in_single = not in_single

        # Both should be closed at end
        if in_double or in_single:
            return False

        return True

    def _write_manifest(self, lines: List[str]) -> None:
        """
        Write lines to the manifest file with validation.

        Args:
            lines: List of lines to write.

        Raises:
            ValueError: If YAML validation fails.
            RuntimeError: If write fails.
        """
        if not self._is_valid_yaml_basic(lines):
            raise ValueError("Invalid YAML: unclosed quotes detected")

        try:
            with open(self.manifest_path, 'w') as f:
                f.writelines(lines)
        except Exception as e:
            raise RuntimeError(f"Failed to write manifest: {e}")

    def update_flag(self, flag: str, value: Optional[str] = None, verbose: bool = False) -> bool:
        """
        Add or update a flag in the container command.
        
        SMART DEDUPLICATION: If flag already exists, removes old instance(s) first,
        then adds the new one with correct value.

        Args:
            flag: Flag name (e.g., '--anonymous-auth').
            value: Flag value (e.g., 'false'). If None, flag added without value.
            verbose: Print debug information.

        Returns:
            True if changes were made, False if already correct.

        Raises:
            ValueError: If command section not found.
        """
        flag = self._normalize_flag(flag)
        value = self._strip_quotes(value) if value else None

        if not self._command_section_indices:
            # More detailed error message with debugging info
            debug_info = f"\nManifest: {self.manifest_path}\n"
            debug_info += f"Total lines: {len(self._lines)}\n"
            debug_info += "First 10 lines:\n"
            for i, line in enumerate(self._lines[:10]):
                debug_info += f"  {i}: {line.rstrip()}\n"
            
            error_msg = f"No command section found in manifest{debug_info if verbose else ''}"
            raise ValueError(error_msg)

        # STEP 1: Remove all existing instances of this flag (deduplication)
        removed_count = 0
        while True:
            flag_index = self._find_flag_in_command(flag)
            if flag_index is None:
                break
            
            removed_count += 1
            old_line = self._lines[flag_index]
            if verbose:
                print(f"[INFO] Removed old instance: {old_line.strip()}")
            del self._lines[flag_index]
            self._command_section_indices.remove(flag_index)
            # Adjust remaining indices
            self._command_section_indices = [
                i if i < flag_index else i - 1
                for i in self._command_section_indices
            ]
        
        # STEP 2: Add the new flag with correct value
        if self._command_section_indices:
            last_command_idx = self._command_section_indices[-1]
            new_line = self._format_flag_line(flag, value)
            if verbose:
                if removed_count > 0:
                    print(f"[INFO] Updated flag: {flag}={value} (removed {removed_count} duplicate(s))")
                else:
                    print(f"[INFO] Added flag: {flag}={value}")
            self._lines.insert(last_command_idx + 1, new_line)
            self._command_section_indices.append(last_command_idx + 1)
            return True
        
        return False

    def remove_flag(self, flag: str, verbose: bool = False) -> bool:
        """
        Remove a flag from the container command.

        Args:
            flag: Flag name (e.g., '--anonymous-auth').
            verbose: Print debug information.

        Returns:
            True if flag was removed, False if flag didn't exist.

        Raises:
            ValueError: If command section not found.
        """
        flag = self._normalize_flag(flag)

        if not self._command_section_indices:
            raise ValueError("No command section found in manifest")

        flag_index = self._find_flag_in_command(flag)

        if flag_index is None:
            if verbose:
                print(f"[DEBUG] Flag {flag} not found, nothing to remove")
            return False  # Flag not found

        if verbose:
            print(f"[DEBUG] Removing flag {flag} from line {flag_index}")
        del self._lines[flag_index]
        self._command_section_indices.remove(flag_index)
        return True

    def merge_plugins(self, flag_name: str, plugins_to_add: List[str], verbose: bool = False) -> bool:
        """
        Intelligently merge plugins into a comma-separated flag.
        
        For flags like '--enable-admission-plugins', reads existing plugins,
        adds new ones (avoiding duplicates), and writes back WITHOUT data loss.

        Args:
            flag_name: The flag name (e.g., 'enable-admission-plugins')
            plugins_to_add: List of plugins to add
            verbose: Print debug information

        Returns:
            True if changes were made, False otherwise

        Raises:
            ValueError: If command section not found.
        """
        flag = self._normalize_flag(flag_name)

        if not self._command_section_indices:
            raise ValueError("No command section found in manifest")

        # STEP 1: Find existing flag line
        flag_index = self._find_flag_in_command(flag)

        # STEP 2: Parse existing plugins (if flag exists)
        existing_plugins = []
        if flag_index is not None:
            existing_line = self._lines[flag_index]
            # Extract value from line (format: "  - --flag=val1,val2,val3")
            if '=' in existing_line:
                value_part = existing_line.split('=', 1)[1].strip()
                existing_plugins = [p.strip() for p in value_part.split(',') if p.strip()]

        # STEP 3: Merge - add new plugins not already present
        merged_plugins = existing_plugins.copy()
        added_plugins = []
        for plugin in plugins_to_add:
            if plugin not in merged_plugins:
                merged_plugins.append(plugin)
                added_plugins.append(plugin)

        # STEP 4: If no new plugins to add, return early
        if not added_plugins:
            if verbose:
                print(f"[INFO] All plugins already present in {flag}")
            return False

        # STEP 5: Write back the merged line
        merged_value = ','.join(merged_plugins)
        new_line = self._format_flag_line(flag, merged_value)

        if flag_index is not None:
            # Update existing line
            self._lines[flag_index] = new_line
            if verbose:
                print(f"[INFO] Merged plugins into {flag}")
                print(f"[INFO]   Existing: {','.join(existing_plugins)}")
                print(f"[INFO]   Added: {','.join(added_plugins)}")
                print(f"[INFO]   Result: {merged_value}")
        else:
            # Create new line
            last_command_idx = self._command_section_indices[-1]
            self._lines.insert(last_command_idx + 1, new_line)
            self._command_section_indices.append(last_command_idx + 1)
            if verbose:
                print(f"[INFO] Created new flag {flag} with plugins: {merged_value}")

        return True

    def apply(self) -> dict:
        """
        Apply changes to the manifest and persist to disk.

        Returns:
            Dict with keys:
                - 'changed': bool - whether changes were made
                - 'backup': str - path to backup file (if changed)
                - 'manifest': str - path to manifest file

        Raises:
            ValueError: If validation fails.
            RuntimeError: If write fails.
        """
        # Check if content actually changed
        if self._lines == self._original_lines:
            return {
                'changed': False,
                'backup': None,
                'manifest': str(self.manifest_path),
                'message': 'No changes needed'
            }

        # Create backup before writing
        backup_path = self._create_backup()

        # Write new manifest
        self._write_manifest(self._lines)

        return {
            'changed': True,
            'backup': backup_path,
            'manifest': str(self.manifest_path),
            'message': 'Manifest updated successfully'
        }

def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description='Safely modify Kubernetes static pod manifests (No PyYAML required)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Add/update a flag with value
  python3 harden_manifests.py \\
    --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \\
    --flag --anonymous-auth \\
    --value false

  # Add a flag without value
  python3 harden_manifests.py \\
    --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \\
    --flag --some-bool-flag

  # Remove a flag
  python3 harden_manifests.py \\
    --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \\
    --flag --old-flag \\
    --ensure absent
        """
    )

    parser.add_argument(
        '--manifest',
        required=True,
        help='Path to the static pod manifest YAML file'
    )
    parser.add_argument(
        '--flag',
        required=True,
        help='Flag name (e.g., --anonymous-auth or anonymous-auth)'
    )
    parser.add_argument(
        '--value',
        default=None,
        help='Flag value (optional for boolean flags)'
    )
    parser.add_argument(
        '--ensure',
        choices=['present', 'absent'],
        default='present',
        help='Whether flag should be present or absent (default: present)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Print debug information'
    )

    args = parser.parse_args()

    try:
        hardener = ManifestHardener(args.manifest)

        if args.ensure == 'present':
            changed = hardener.update_flag(args.flag, args.value, verbose=args.verbose)
        else:  # absent
            changed = hardener.remove_flag(args.flag, verbose=args.verbose)

        result = hardener.apply()

        if result['changed']:
            if args.verbose:
                print(f"[PASS] {result['message']}")
                print(f"[INFO] Manifest: {result['manifest']}")
                if result['backup']:
                    print(f"[INFO] Backup: {result['backup']}")
        else:
            if args.verbose:
                print(f"[PASS] No changes needed (already correct)")

        sys.exit(0)

    except FileNotFoundError as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"[FAIL] Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
