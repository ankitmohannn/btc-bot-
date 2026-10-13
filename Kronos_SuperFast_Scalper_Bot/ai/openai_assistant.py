"""
SmartScalper V2 — Official OpenAI Assistant Engine
Dedicated Read-Only AI Workspace Assistant for MetaTrader 5 & Vibe-Trading.

Model: gpt-5.6
Authentication: OPENAI_API_KEY environment variable only (never hardcoded).
Permissions: Strictly READ-ONLY workspace inspection tools.
"""

import os
import sys
import glob
import re
import json
import csv
from typing import Dict, List, Any, Optional

# Force UTF-8 on Windows stdout/stderr if supported
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Root directory of the repository
_WORKSPACE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def _safe_rel_path(path: str) -> str:
    """Normalize and ensure path stays within workspace."""
    abs_path = os.path.abspath(os.path.join(_WORKSPACE_ROOT, path))
    if not abs_path.startswith(_WORKSPACE_ROOT):
        raise ValueError(f"Access denied: path outside workspace ({path})")
    return abs_path

# ==============================================================================
# Controlled Read-Only Workspace Tools
# ==============================================================================

def tool_read_file(file_path: str, start_line: int = 1, max_lines: int = 120) -> str:
    """Read lines of a workspace file with line numbers."""
    try:
        abs_path = _safe_rel_path(file_path)
        if not os.path.exists(abs_path):
            return f"Error: File '{file_path}' does not exist in workspace."
        if os.path.isdir(abs_path):
            return f"Error: '{file_path}' is a directory, not a file. Use list_directory."

        print(f"\n[TOOL] [READ] {file_path} (Lines {start_line} to {start_line + max_lines - 1})")

        with open(abs_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

        total_lines = len(lines)
        start_idx = max(0, start_line - 1)
        end_idx = min(total_lines, start_idx + max_lines)
        selected = lines[start_idx:end_idx]

        output = [f"--- File: {file_path} (Total lines: {total_lines}, Showing {start_idx+1}-{end_idx}) ---"]
        for idx, line in enumerate(selected, start=start_idx + 1):
            output.append(f"{idx:4d}: {line.rstrip()}")

        return "\n".join(output)
    except Exception as e:
        return f"Error reading file '{file_path}': {str(e)}"

def tool_list_directory(dir_path: str = ".") -> str:
    """List files and subdirectories in any workspace folder."""
    try:
        abs_path = _safe_rel_path(dir_path)
        if not os.path.exists(abs_path):
            return f"Error: Directory '{dir_path}' does not exist."

        print(f"\n[TOOL] [LIST] {dir_path if dir_path != '.' else 'workspace root'}")

        items = []
        for item in sorted(os.listdir(abs_path)):
            if item in [".git", "__pycache__", ".agents", ".gemini"]:
                continue
            item_abs = os.path.join(abs_path, item)
            is_dir = os.path.isdir(item_abs)
            size = "" if is_dir else f" ({os.path.getsize(item_abs):,} bytes)"
            items.append(f"{'[DIR] ' if is_dir else '[FILE]'} {item}{size}")

        return f"Contents of '{dir_path}':\n" + "\n".join(items)
    except Exception as e:
        return f"Error listing directory '{dir_path}': {str(e)}"

def tool_search_code(query: str, file_pattern: str = "*") -> str:
    """Search for text or regex patterns across workspace files."""
    try:
        print(f"\n[TOOL] [SEARCH] \"{query}\" (Pattern: {file_pattern})")
        matches = []
        pattern_re = re.compile(query, re.IGNORECASE)

        valid_extensions = {".mq5", ".mqh", ".py", ".yaml", ".yml", ".md", ".csv", ".json", ".txt", ".bat"}

        for root, dirs, files in os.walk(_WORKSPACE_ROOT):
            dirs[:] = [d for d in dirs if d not in [".git", "__pycache__", ".agents", ".gemini", "node_modules"]]
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext not in valid_extensions:
                    continue
                if file_pattern != "*" and not glob.fnmatch.fnmatch(file, file_pattern):
                    continue

                abs_file = os.path.join(root, file)
                rel_file = os.path.relpath(abs_file, _WORKSPACE_ROOT)

                try:
                    with open(abs_file, "r", encoding="utf-8", errors="ignore") as f:
                        for line_no, line in enumerate(f, 1):
                            if pattern_re.search(line):
                                matches.append(f"{rel_file}:{line_no}: {line.strip()[:140]}")
                                if len(matches) >= 30:
                                    break
                except Exception:
                    continue
            if len(matches) >= 30:
                break

        if not matches:
            return f"No matches found for '{query}'."
        return f"Found {len(matches)} matches (showing up to 30):\n" + "\n".join(matches)
    except Exception as e:
        return f"Error searching code for '{query}': {str(e)}"

def tool_get_project_structure() -> str:
    """Return high-level architecture and component map of the workspace."""
    print("\n[TOOL] [STRUCTURE] Inspecting project architecture structure")
    return """
=== KRONOS SMARTSCALPER V2 WORKSPACE STRUCTURE ===
1. MQL5 Expert Advisors:
   - SmartScalper_V2.mq5: Main production-grade hybrid AI/deterministic scalper
   - Kronos_SuperFast_Scalper_EA.mq5: Baseline untouched EA

2. Include Modules (Include/SmartScalper/):
   - SmartScalper_Types.mqh: Core data structures, enums, signal packets
   - SmartScalper_Config.mqh: Master input configuration parameters
   - SmartScalper_FeatureEngine.mqh: Multi-timeframe indicator calculations (EMA, RSI, ADX, ATR)
   - SmartScalper_SMC.mqh: Smart Money Concepts (BOS, CHoCH, Liquidity Sweeps, FVGs, Order Blocks)
   - SmartScalper_MTF.mqh: Multi-timeframe synergy (M1, M5, M15, H1)
   - SmartScalper_Regime.mqh: Market regime detection (Trending, Range, Breakout, Volatility)
   - SmartScalper_Scoring.mqh: 0-100 institutional setup scoring engine
   - SmartScalper_RiskEngine.mqh: Dynamic capital-proportional lot sizing, structural SL/TP
   - SmartScalper_TradeManager.mqh: Order execution, Auto Break-Even, Trailing Stop
   - SmartScalper_Filters.mqh: Quality gating, spread filter, session profiles, anti-overtrading
   - SmartScalper_AIBridge.mqh: Resilient IPC bridge with Python Vibe-Trading
   - SmartScalper_Journal.mqh: Trade journaling and metrics export
   - SmartScalper_HUD.mqh: Real-time on-chart diagnostics dashboard panel

3. Python AI Layer (ai/):
   - ai/bridge/ai_bridge_server.py: Real-time atomic IPC bridge poller
   - ai/bridge/vibe_trading_adapter.py: HKUDS Vibe-Trading AI model connector
   - ai/openai_assistant.py: OpenAI-powered workspace inspection assistant

4. Web Analytics Dashboard (dashboard/):
   - index.html, styles.css, app.js, server.py: Glassmorphic dark theme dashboard
   - data/backtest_results.json: Multi-TF and 10,000-run Monte Carlo simulation database

5. Testing & Validation Harnesses (tests/):
   - multi_timeframe_backtester.py: Multi-TF backtester and Monte Carlo engine
   - phase3b_adversarial_engine.py: 18-stage adversarial stress testing harness
   - ablation_study_engine.py: 4-configuration ablation study engine
   - phase4_forward_validator.py: Forward simulation harness

6. Configuration & Reports:
   - config.yaml: System parameters and AI thresholds
   - PHASE_*.md: Validation and adversarial reports
   - *.csv: Historical backtest, Monte Carlo, and stress test datasets
"""

def tool_read_csv_summary(file_path: str, max_rows: int = 15) -> str:
    """Inspect CSV header, total rows, and sample head records."""
    try:
        abs_path = _safe_rel_path(file_path)
        if not os.path.exists(abs_path):
            return f"Error: CSV file '{file_path}' does not exist."

        print(f"\n[TOOL] [CSV] Analyzing: {file_path}")

        with open(abs_path, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            rows = list(reader)

        if not rows:
            return f"CSV file '{file_path}' is empty."

        header = rows[0]
        data_rows = rows[1:]
        total_data_rows = len(data_rows)

        summary = [
            f"=== CSV Summary: {file_path} ===",
            f"Total Columns: {len(header)}",
            f"Columns: {', '.join(header)}",
            f"Total Data Rows: {total_data_rows:,}",
            f"\nSample Rows (Showing top {min(max_rows, total_data_rows)}):"
        ]

        for i, row in enumerate(data_rows[:max_rows], 1):
            summary.append(f"Row {i:3d}: {', '.join(row)}")

        return "\n".join(summary)
    except Exception as e:
        return f"Error reading CSV '{file_path}': {str(e)}"

def tool_list_reports_and_logs() -> str:
    """Discover all Markdown validation reports and compilation log files."""
    print("\n[TOOL] [REPORTS] Listing reports and log files")
    reports = glob.glob(os.path.join(_WORKSPACE_ROOT, "*.md"))
    logs = glob.glob(os.path.join(_WORKSPACE_ROOT, "*.log"))
    csvs = glob.glob(os.path.join(_WORKSPACE_ROOT, "*.csv"))

    out = ["=== AVAILABLE REPORTS, LOGS & CSV DATASETS ==="]
    out.append("\nMarkdown Reports:")
    for r in sorted(reports):
        out.append(f"  - {os.path.basename(r)}")

    out.append("\nCompilation & Runtime Logs:")
    for l in sorted(logs):
        out.append(f"  - {os.path.basename(l)}")

    out.append("\nBacktest & Stress Test Datasets (CSV):")
    for c in sorted(csvs):
        out.append(f"  - {os.path.basename(c)}")

    return "\n".join(out)

# Tool Dispatch Table
AVAILABLE_TOOLS = {
    "read_file": tool_read_file,
    "list_directory": tool_list_directory,
    "search_code": tool_search_code,
    "get_project_structure": tool_get_project_structure,
    "read_csv_summary": tool_read_csv_summary,
    "list_reports_and_logs": tool_list_reports_and_logs
}

# OpenAI Tool Specifications
OPENAI_TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read contents of a workspace file with line numbers. Use this to inspect MQL5 EA files, Python code, config.yaml, Markdown reports, or logs.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "Relative path to file in workspace (e.g. 'SmartScalper_V2.mq5', 'Include/SmartScalper/SmartScalper_RiskEngine.mqh', 'config.yaml')"},
                    "start_line": {"type": "integer", "description": "Starting line number (1-indexed). Defaults to 1."},
                    "max_lines": {"type": "integer", "description": "Number of lines to read. Defaults to 100."}
                },
                "required": ["file_path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_directory",
            "description": "List files and folders inside any workspace directory.",
            "parameters": {
                "type": "object",
                "properties": {
                    "dir_path": {"type": "string", "description": "Relative directory path (e.g. '.', 'Include/SmartScalper', 'tests', 'ai', 'dashboard'). Defaults to '.'."}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_code",
            "description": "Search for code tokens, variable names, functions, or text across all project files.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query or regex (e.g. 'CalculateRiskLotSize', 'InpMinSLPoints', 'SESSION_LONDON')"},
                    "file_pattern": {"type": "string", "description": "Optional glob filter (e.g. '*.mqh', '*.py', '*.mq5'). Defaults to '*'."}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_project_structure",
            "description": "Get a comprehensive architectural overview of all components, modules, EAs, test engines, and data files in the workspace.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_csv_summary",
            "description": "Inspect backtest results, trade journals, or stress test CSV files with column headers and sample data rows.",
            "parameters": {
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "Relative path to CSV file (e.g. 'MONTE_CARLO_RESULTS.csv', 'smart_scalper_forward_trades.csv')"},
                    "max_rows": {"type": "integer", "description": "Maximum sample data rows to inspect. Defaults to 15."}
                },
                "required": ["file_path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_reports_and_logs",
            "description": "List all markdown validation reports, compilation log files, and backtest CSV datasets.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    }
]

SYSTEM_PROMPT = """You are the Institutional AI Engineering Assistant for the Kronos SmartScalper V2 MetaTrader 5 trading system.

Your role:
- Inspect and analyze the actual code, configuration, logs, CSV backtest results, and architecture of this repository.
- Explain MQL5 EA logic, Smart Money Concepts (BOS, CHoCH, FVG, Order Blocks, Liquidity Sweeps), risk formulas, and Python bridge mechanics.
- Troubleshoot issues, identify logic bottlenecks, and suggest code improvements.

CRITICAL RULES:
1. Grounding: You MUST retrieve and inspect the relevant workspace files using your tools before answering questions about specific code, settings, or test results.
2. No Hallucinations: Do not assume or hallucinate file contents or parameters. If something is not in the workspace, state it explicitly.
3. Read-Only: You have read-only inspection access. You do not modify files, execute trades, or run shell commands.
4. Precision: Provide concise, clear, and mathematically accurate explanations referencing specific file paths and line ranges.
"""

DEFAULT_MODAL_ENDPOINT = "https://shramadhruv0747--ep-gpt-oss-120b-server.us-west.modal.direct/v1"

def run_assistant_cli():
    """Main interactive terminal loop for Modal Endpoint (GPT-OSS 120B) Assistant."""
    # 1. Resolve Modal Endpoint & Credentials
    base_url = os.getenv("MODAL_API_BASE_URL", DEFAULT_MODAL_ENDPOINT)
    api_key = os.getenv("MODAL_API_KEY") or os.getenv("OPENAI_API_KEY")
    model_name = os.getenv("OPENAI_MODEL", "gpt-oss-120b")

    # If base_url does not end with /v1, append it
    if base_url and not base_url.endswith("/v1") and not "/v1/" in base_url:
        base_url = base_url.rstrip("/") + "/v1"

    if not api_key:
        print("\n" + "="*70)
        print("🔑 MODAL ENDPOINT AUTHENTICATION")
        print("="*70)
        print(f"Endpoint: {base_url}")
        print("Target Model: GPT-OSS 120B")
        print("\nPlease enter your Modal API Key / Token below")
        print("(or set $env:MODAL_API_KEY in your terminal):")
        try:
            user_key = input("Modal API Key > ").strip()
            if user_key:
                api_key = user_key
                os.environ["MODAL_API_KEY"] = user_key
            else:
                api_key = "modal-token"
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            sys.exit(0)
        print("="*70 + "\n")

    try:
        import httpx
        from openai import OpenAI
    except ImportError:
        print("\n❌ Error: 'openai' or 'httpx' package missing. Run: pip install openai httpx\n")
        sys.exit(1)

    # SSL-resilient HTTP client for Modal endpoints on Windows
    http_client = httpx.Client(verify=False, timeout=60.0)

    client = OpenAI(
        base_url=base_url,
        api_key=api_key,
        http_client=http_client
    )
    endpoint_display = base_url

    # Multi-turn conversation state
    messages: List[Dict[str, Any]] = [
        {"role": "system", "content": SYSTEM_PROMPT}
    ]

    print("\n" + "="*70)
    print("⚡ ANTIGRAVITY -> MODAL GPT-OSS 120B ASSISTANT READY")
    print(f"🤖 Model: {model_name} | Backend: Modal Endpoint | Security: Read-Only")
    print(f"🌐 Endpoint: {endpoint_display}")
    print("="*70)
    print("Type your question below (or type 'exit' / 'quit' to end session).\n")

    while True:
        try:
            user_input = input("Ask > ").strip()
            if not user_input:
                continue
            if user_input.lower() in ["exit", "quit", "q"]:
                print("\n[*] Exiting OpenAI Assistant. Goodbye!\n")
                break

            messages.append({"role": "user", "content": user_input})

            # Multi-step tool calling loop
            while True:
                response = client.chat.completions.create(
                    model=model_name,
                    messages=messages,
                    tools=OPENAI_TOOL_SCHEMAS,
                    tool_choice="auto"
                )

                choice = response.choices[0]
                msg = choice.message

                # If the model requested tool calls
                if msg.tool_calls:
                    # Append assistant message with tool calls
                    messages.append(msg.to_dict() if hasattr(msg, "to_dict") else {
                        "role": "assistant",
                        "content": msg.content or "",
                        "tool_calls": [
                            {
                                "id": tc.id,
                                "type": tc.type,
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments
                                }
                            } for tc in msg.tool_calls
                        ]
                    })

                    for tool_call in msg.tool_calls:
                        func_name = tool_call.function.name
                        tool_func = AVAILABLE_TOOLS.get(func_name)

                        if tool_func:
                            try:
                                args = json.loads(tool_call.function.arguments) if tool_call.function.arguments else {}
                                result = tool_func(**args)
                            except Exception as ex:
                                result = f"Tool execution error: {str(ex)}"
                        else:
                            result = f"Error: Unknown tool '{func_name}'."

                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": str(result)
                        })
                else:
                    # Final text response
                    final_text = msg.content or ""
                    messages.append({"role": "assistant", "content": final_text})
                    print("\n" + "-"*70)
                    print(final_text)
                    print("-"*(70) + "\n")
                    break

        except KeyboardInterrupt:
            print("\n\n[*] Session interrupted by user. Exiting.\n")
            break
        except Exception as e:
            print(f"\n❌ Error during execution: {str(e)}\n")

if __name__ == "__main__":
    run_assistant_cli()
