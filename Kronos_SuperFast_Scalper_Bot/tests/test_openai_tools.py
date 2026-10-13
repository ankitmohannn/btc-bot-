"""
Unit Verification for OpenAI Assistant Read-Only Tools
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from ai.openai_assistant import (
    tool_read_file,
    tool_list_directory,
    tool_search_code,
    tool_get_project_structure,
    tool_read_csv_summary,
    tool_list_reports_and_logs,
    _safe_rel_path
)

class TestOpenAIAssistantTools(unittest.TestCase):
    def test_read_file_existing(self):
        res = tool_read_file("config.yaml", start_line=1, max_lines=15)
        self.assertIn("BTCUSD", res)
        self.assertIn("timeframe: M5", res)

    def test_read_file_mql5(self):
        res = tool_read_file("Include/SmartScalper/SmartScalper_RiskEngine.mqh", start_line=30, max_lines=25)
        self.assertIn("CalculateRiskLotSize", res)

    def test_list_directory(self):
        res = tool_list_directory("Include/SmartScalper")
        self.assertIn("SmartScalper_RiskEngine.mqh", res)
        self.assertIn("SmartScalper_SMC.mqh", res)

    def test_search_code(self):
        res = tool_search_code("InpMinSLPoints", "*.mqh")
        self.assertIn("SmartScalper_Config.mqh", res)

    def test_get_project_structure(self):
        res = tool_get_project_structure()
        self.assertIn("SmartScalper_V2.mq5", res)
        self.assertIn("Include/SmartScalper/", res)

    def test_read_csv_summary(self):
        res = tool_read_csv_summary("MONTE_CARLO_RESULTS.csv", max_rows=5)
        self.assertIn("=== CSV Summary", res)

    def test_list_reports_and_logs(self):
        res = tool_list_reports_and_logs()
        self.assertIn("Markdown Reports:", res)
        self.assertIn("PHASE_4_FORWARD_VALIDATION_REPORT.md", res)

    def test_security_sandbox(self):
        with self.assertRaises(ValueError):
            _safe_rel_path("../../Windows/System32")

if __name__ == "__main__":
    unittest.main()
