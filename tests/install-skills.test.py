import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / 'scripts/install-skills.py'

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='megatask test ')
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1')
    def tearDown(self):
        self.temp.cleanup()
    def run_install(self, *args):
        return subprocess.run(['python3', str(INSTALLER), *args], env=self.env,
                              text=True, capture_output=True)
    def test_shared_install_idempotent_and_licensed(self):
        for target in ('codex', 'agents'):
            result = self.run_install('--target', target)
            self.assertEqual(result.returncode, 0, result.stderr)
        skills = self.home / '.agents/skills'
        self.assertEqual(len(list(skills.iterdir())), 17)
        for path in skills.iterdir():
            self.assertTrue(path.is_symlink())
            self.assertIn('Maxence Bouvier', (path / 'LICENSE').read_text())
            self.assertIn('Maxence Bouvier', (path / 'NOTICE').read_text())
            self.assertTrue((path / 'SKILL.md').exists())
        self.assertTrue((skills / 'manager/scripts/mt-worker.sh').exists())
    def test_gemini_native_path(self):
        result = self.run_install('--target', 'gemini')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.gemini/skills/megatask/SKILL.md').exists())
    def test_conflict_does_not_partially_install(self):
        destination = self.home / '.agents/skills'
        (destination / 'manager').mkdir(parents=True)
        result = self.run_install('--target', 'codex')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([p.name for p in destination.iterdir()], ['manager'])
    def test_dry_run_does_not_create_destination(self):
        result = self.run_install('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / '.agents').exists())
    def test_custom_destination_and_uninstall_preserves_foreign_entries(self):
        destination = self.home / 'other client/skills'
        result = self.run_install('--skills-dir', str(destination))
        self.assertEqual(result.returncode, 0, result.stderr)
        (destination / 'manager').unlink()
        (destination / 'manager').mkdir()
        result = self.run_install('--skills-dir', str(destination), '--uninstall')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([p.name for p in destination.iterdir()], ['manager'])
    def test_project_scope(self):
        result = self.run_install('--project', str(self.home), '--target', 'codex')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.agents/skills/megatask').is_symlink())

if __name__ == '__main__':
    unittest.main()
