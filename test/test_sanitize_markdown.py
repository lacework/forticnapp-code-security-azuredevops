#!/usr/bin/env python3
import os
import re
import sys
import unittest

import importlib.util

_spec = importlib.util.spec_from_file_location(
    'sanitize_markdown',
    os.path.join(os.path.dirname(__file__), '..', 'scripts', 'sanitize-markdown.py'),
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
sanitize = _mod.sanitize

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), 'fixtures')


class TestSanitizeMarkdown(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(os.path.join(FIXTURES_DIR, 'github-markdown-input.md')) as f:
            cls.output = sanitize(f.read())

    def test_no_html_tags_remain(self):
        for tag in ['<table', '<details', '<summary', '<ins>', '<sup>', '&nbsp;', '<!---']:
            self.assertNotIn(tag, self.output, f'Found leftover HTML: {tag}')

    def test_section_headings_present(self):
        for heading in ['3rd Party Vulnerabilities', 'Internal Code',
                        'Hard-coded Secrets', 'Violations']:
            self.assertIn(f'**{heading}**', self.output)

    def test_markdown_tables_well_formed(self):
        in_table = False
        expected_cols = None
        for line in self.output.split('\n'):
            stripped = line.strip()
            if stripped.startswith('|') and stripped.endswith('|'):
                cols = stripped.count('|') - 1
                if not in_table:
                    in_table = True
                    expected_cols = cols
                else:
                    self.assertEqual(cols, expected_cols,
                                     f'Column count mismatch: expected {expected_cols}, '
                                     f'got {cols} in: {stripped[:80]}')
            else:
                in_table = False
                expected_cols = None

    def test_links_converted_to_markdown(self):
        self.assertRegex(self.output, r'\[CVE-\d{4}-\d+\]')
        self.assertNotIn('<a ', self.output)


if __name__ == '__main__':
    unittest.main()
