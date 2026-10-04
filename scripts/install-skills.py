#!/usr/bin/env python3
"""Link Megatask skills into a coding CLI's discovery directory (Python 3.8+)."""
import argparse
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {'agents': '.agents/skills', 'codex': '.agents/skills',
           'gemini': '.gemini/skills', 'claude': '.claude/skills'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=TARGETS, default='agents')
    parser.add_argument('--project', type=Path, help='Project scope instead of user scope')
    parser.add_argument('--skills-dir', type=Path, help='Explicit discovery directory for another CLI')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--uninstall', action='store_true', help='Remove only links owned by this checkout')
    args = parser.parse_args()
    if args.project and args.skills_dir:
        parser.error('--project and --skills-dir are mutually exclusive')
    base = args.project.expanduser().resolve() if args.project else Path.home()
    destination = (args.skills_dir.expanduser().absolute() if args.skills_dir
                   else base / TARGETS[args.target])
    sources = sorted(ROOT.glob('plugins/*/skills/*/SKILL.md'))
    sources += sorted(ROOT.glob('portable-skills/*/SKILL.md'))
    links = {}
    for skill in sources:
        source = skill.parent
        if source.name in links:
            parser.error('Duplicate skill directory: ' + source.name)
        if not all((source / f).is_file() for f in ('LICENSE', 'NOTICE')):
            parser.error('Missing license/notice: ' + source.name)
        links[source.name] = source
    if not links:
        parser.error('No skills found in this checkout')
    owned = lambda link, source: link.is_symlink() and link.resolve() == source.resolve()
    if not args.uninstall:
        conflicts = [str(destination / name) for name, source in links.items()
                     if os.path.lexists(destination / name) and not owned(destination / name, source)]
        if conflicts:
            parser.error('Existing entries would be overwritten; no changes made:\n' + '\n'.join(conflicts))
    created = []
    try:
        for name, source in links.items():
            link = destination / name
            if args.uninstall:
                if owned(link, source):
                    print('Remove ' + str(link))
                    if not args.dry_run:
                        link.unlink()
            elif owned(link, source):
                print('Already installed: ' + name)
            else:
                print('Link ' + str(link) + ' -> ' + str(source))
                if not args.dry_run:
                    destination.mkdir(parents=True, exist_ok=True)
                    link.symlink_to(source, target_is_directory=True)
                    created.append(link)
    except OSError as error:
        for link in reversed(created):
            link.unlink()
        print('Installation failed: ' + str(error), file=sys.stderr)
        return 1
    print('Done. Keep this checkout in place; refresh skills or restart your CLI.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
