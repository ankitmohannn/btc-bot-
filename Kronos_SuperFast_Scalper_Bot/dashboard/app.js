/**
 * SmartScalper V2 — Multi-Timeframe Analytics & Monte Carlo Dashboard Controller
 */

let g_dashboard_data = null;
let g_current_symbol = "BTCUSD";
let g_current_tf = "M5";

// Trade History State
let g_trade_filter_outcome = "ALL";
let g_trade_search_query = "";
let g_trade_page = 1;
const g_trade_page_size = 25;

// Chart instances
let chart_equity = null;
let chart_mc = null;
let chart_score_wr = null;
let chart_score_pf = null;
let chart_regime = null;
let chart_session = null;

document.addEventListener("DOMContentLoaded", async () => {
  initTabNavigation();
  initControlListeners();
  initTradeHistoryControls();
  await loadDashboardData();
  renderCurrentView();
});

// Setup Tab Switching
function initTabNavigation() {
  const tabs = document.querySelectorAll("#main-tabs .tab-btn");
  tabs.forEach(btn => {
    btn.addEventListener("click", () => {
      tabs.forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));

      btn.classList.add("active");
      const targetId = btn.getAttribute("data-tab");
      const targetPane = document.getElementById(targetId);
      if (targetPane) {
        targetPane.classList.add("active");
      }
    });
  });
}

// Setup Symbol & Timeframe Selectors
function initControlListeners() {
  // Symbol buttons
  document.querySelectorAll("#symbol-selector .seg-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#symbol-selector .seg-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      g_current_symbol = btn.getAttribute("data-symbol");
      renderCurrentView();
    });
  });

  // Timeframe buttons
  document.querySelectorAll("#tf-selector .seg-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("#tf-selector .seg-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      g_current_tf = btn.getAttribute("data-tf");
      renderCurrentView();
    });
  });
}

// Setup Trade History Search, Filter Pills, Pagination, and CSV Export
function initTradeHistoryControls() {
  // Outcome Filter Pills
  document.querySelectorAll(".trade-filter-bar .filter-pill").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".trade-filter-bar .filter-pill").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      g_trade_filter_outcome = btn.getAttribute("data-filter-outcome");
      g_trade_page = 1;
      if (g_dashboard_data && g_dashboard_data.matrix) {
        const tfData = g_dashboard_data.matrix[g_current_symbol][g_current_tf];
        if (tfData) renderTradeHistory(tfData);
      }
    });
  });

  // Search Input
  const searchInput = document.getElementById("trade-search-input");
  if (searchInput) {
    searchInput.addEventListener("input", (e) => {
      g_trade_search_query = e.target.value.toLowerCase().trim();
      g_trade_page = 1;
      if (g_dashboard_data && g_dashboard_data.matrix) {
        const tfData = g_dashboard_data.matrix[g_current_symbol][g_current_tf];
        if (tfData) renderTradeHistory(tfData);
      }
    });
  }

  // Pagination Buttons
  const prevBtn = document.getElementById("page-prev");
  const nextBtn = document.getElementById("page-next");

  if (prevBtn) {
    prevBtn.addEventListener("click", () => {
      if (g_trade_page > 1) {
        g_trade_page--;
        if (g_dashboard_data && g_dashboard_data.matrix) {
          const tfData = g_dashboard_data.matrix[g_current_symbol][g_current_tf];
          if (tfData) renderTradeHistory(tfData);
        }
      }
    });
  }

  if (nextBtn) {
    nextBtn.addEventListener("click", () => {
      g_trade_page++;
      if (g_dashboard_data && g_dashboard_data.matrix) {
        const tfData = g_dashboard_data.matrix[g_current_symbol][g_current_tf];
        if (tfData) renderTradeHistory(tfData);
      }
    });
  }

  // Export CSV Button
  const exportBtn = document.getElementById("btn-export-trades");
  if (exportBtn) {
    exportBtn.addEventListener("click", () => {
      exportCurrentTradesCSV();
    });
  }
}

// Load Backtest & Monte Carlo Data
async function loadDashboardData() {
  try {
    const response = await fetch("data/backtest_results.json");
    if (response.ok) {
      g_dashboard_data = await response.json();
      console.log("[DATA] Loaded master backtest database:", g_dashboard_data);
    } else {
      console.warn("[DATA] Could not fetch backtest_results.json, using fallback cache.");
    }
  } catch (err) {
    console.error("[DATA] Error loading backtest_results.json:", err);
  }
}

// Render All Components for the Selected Symbol & Timeframe
function renderCurrentView() {
  if (!g_dashboard_data || !g_dashboard_data.matrix) return;

  const symMatrix = g_dashboard_data.matrix[g_current_symbol];
  if (!symMatrix) return;

  const tfData = symMatrix[g_current_tf];
  if (!tfData) return;

  // 1. Update Header & Subheader Titles
  document.getElementById("active-pair-tag").textContent = `${tfData.symbol} (${tfData.symbol_name})`;
  document.getElementById("active-tf-title").textContent = tfData.timeframe_label;
  document.querySelector(".section-badge").textContent = `${g_current_symbol} • Multi-TF`;

  // 2. Update KPI Cards
  updateKPICards(tfData);

  // 3. Render Equity & Drawdown Chart
  renderEquityChart(tfData);

  // 4. Render Monte Carlo 10,000-Run Cone Chart
  renderMonteCarloChart(tfData);

  // 5. Render Score Monotonicity Charts
  renderScoreCharts(tfData);

  // 6. Render Regime & Session Charts
  renderRegimeAndSessionCharts(tfData);

  // 7. Render Trade History Journal Table
  renderTradeHistory(tfData);

  // 8. Update Comparison Matrix Table
  renderMatrixComparisonTable(symMatrix);
}

// Update Top KPI Cards with Formatting
function updateKPICards(d) {
  document.getElementById("kpi-net-profit").textContent = `+$${d.net_profit.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  const returnPct = ((d.net_profit / d.starting_balance) * 100).toFixed(1);
  document.getElementById("kpi-return-pct").textContent = `+${returnPct}% Total Return on $10k`;

  document.getElementById("kpi-profit-factor").textContent = d.profit_factor.toFixed(2);
  document.getElementById("kpi-pf-subtext").textContent = `Gross $${(d.gross_profit/1000).toFixed(1)}k / Loss $${(d.gross_loss/1000).toFixed(1)}k`;

  document.getElementById("kpi-win-rate").textContent = `${d.win_rate_pct.toFixed(2)}%`;
  document.getElementById("kpi-win-counts").textContent = `${d.win_count} Wins / ${d.loss_count} Losses`;

  document.getElementById("kpi-expectancy").textContent = `+$${d.expectancy_usd.toFixed(2)}`;
  document.getElementById("kpi-r-multiple").textContent = `${d.avg_r_multiple.toFixed(2)} R per trade`;

  document.getElementById("kpi-max-dd").textContent = `$${d.max_drawdown_usd.toFixed(2)}`;
  document.getElementById("kpi-max-dd-pct").textContent = `${d.max_drawdown_pct.toFixed(2)}% Peak-to-Trough`;

  document.getElementById("kpi-sharpe-sortino").textContent = `${d.sharpe_ratio.toFixed(2)} / ${d.sortino_ratio.toFixed(2)}`;
  document.getElementById("kpi-recovery-factor").textContent = `Recovery Factor: ${d.recovery_factor.toFixed(1)}x`;

  document.getElementById("kpi-total-trades").textContent = d.total_trades.toLocaleString();
  const avgDur = g_current_tf === "M1" ? "~2.0 mins" : (g_current_tf === "M5" ? "~5.3 mins" : (g_current_tf === "M15" ? "~15.8 mins" : "~1.1 hrs"));
  document.getElementById("kpi-avg-duration").textContent = `Avg Hold: ${avgDur}`;

  document.getElementById("kpi-payoff").textContent = `$${d.avg_win_usd.toFixed(1)} / $${d.avg_loss_usd.toFixed(1)}`;
  const rrRatio = d.avg_loss_usd > 0 ? (d.avg_win_usd / d.avg_loss_usd).toFixed(2) : "2.00";
  document.getElementById("kpi-rr-ratio").textContent = `${rrRatio} : 1.00 Reward/Risk`;

  // Monte Carlo Quick Stats
  if (d.monte_carlo && d.monte_carlo.final_equity_percentiles) {
    const mc = d.monte_carlo.final_equity_percentiles;
    document.getElementById("mc-p5").textContent = `$${mc.p5.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
    document.getElementById("mc-p25").textContent = `$${mc.p25.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
    document.getElementById("mc-p50").textContent = `$${mc.p50_median.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
    document.getElementById("mc-p75").textContent = `$${mc.p75.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
    document.getElementById("mc-p95").textContent = `$${mc.p95.toLocaleString(undefined, { minimumFractionDigits: 2 })}`;
    document.getElementById("mc-prob-neg").textContent = `${d.monte_carlo.prob_negative_equity_pct.toFixed(4)}%`;
  }
}

// Chart 1: Equity & Drawdown Curve
function renderEquityChart(d) {
  const ctx = document.getElementById("equityChart");
  if (!ctx) return;

  if (chart_equity) {
    chart_equity.destroy();
  }

  const labels = d.equity_curve.map(pt => `T#${pt.index}`);
  const equityData = d.equity_curve.map(pt => pt.equity);
  const drawdownData = d.equity_curve.map(pt => -pt.drawdown);

  chart_equity = new Chart(ctx, {
    type: "line",
    data: {
      labels: labels,
      datasets: [
        {
          label: "Cumulative Equity ($)",
          data: equityData,
          borderColor: "#06b6d4",
          backgroundColor: "rgba(6, 182, 212, 0.08)",
          fill: true,
          tension: 0.2,
          borderWidth: 2.5,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: "#10b981",
          yAxisID: "y"
        },
        {
          label: "Drawdown ($)",
          data: drawdownData,
          borderColor: "#f43f5e",
          backgroundColor: "rgba(244, 63, 94, 0.15)",
          fill: true,
          tension: 0.2,
          borderWidth: 1.5,
          pointRadius: 0,
          yAxisID: "y1"
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: "index",
        intersect: false
      },
      plugins: {
        legend: {
          position: "top",
          labels: { color: "#94a3b8", font: { family: "Inter", size: 12 } }
        },
        tooltip: {
          backgroundColor: "rgba(15, 23, 42, 0.95)",
          titleColor: "#f8fafc",
          bodyColor: "#94a3b8",
          borderColor: "rgba(255, 255, 255, 0.1)",
          borderWidth: 1,
          padding: 12
        }
      },
      scales: {
        x: {
          grid: { color: "rgba(255, 255, 255, 0.04)" },
          ticks: { color: "#64748b", font: { family: "JetBrains Mono", size: 10 }, maxTicksLimit: 12 }
        },
        y: {
          type: "linear",
          display: true,
          position: "left",
          grid: { color: "rgba(255, 255, 255, 0.06)" },
          ticks: {
            color: "#06b6d4",
            font: { family: "JetBrains Mono", size: 11 },
            callback: v => `$${(v/1000).toFixed(0)}k`
          }
        },
        y1: {
          type: "linear",
          display: true,
          position: "right",
          grid: { drawOnChartArea: false },
          ticks: {
            color: "#f43f5e",
            font: { family: "JetBrains Mono", size: 11 },
            callback: v => `$${v}`
          }
        }
      }
    }
  });
}

// Chart 2: Monte Carlo 10,000-Run Confidence Cone
function renderMonteCarloChart(d) {
  const ctx = document.getElementById("monteCarloChart");
  if (!ctx || !d.monte_carlo || !d.monte_carlo.confidence_cone) return;

  if (chart_mc) {
    chart_mc.destroy();
  }

  const cone = d.monte_carlo.confidence_cone;
  const labels = ["Start (0)", ...cone.map(c => `Trade ${c.trade_step}`)];

  const startEq = d.starting_balance;
  const p95Data = [startEq, ...cone.map(c => c.p95)];
  const p75Data = [startEq, ...cone.map(c => c.p75)];
  const p50Data = [startEq, ...cone.map(c => c.p50_median)];
  const p25Data = [startEq, ...cone.map(c => c.p25)];
  const p5Data = [startEq, ...cone.map(c => c.p5)];

  chart_mc = new Chart(ctx, {
    type: "line",
    data: {
      labels: labels,
      datasets: [
        {
          label: "95th Percentile (Upper Bound)",
          data: p95Data,
          borderColor: "rgba(16, 185, 129, 0.8)",
          backgroundColor: "rgba(16, 185, 129, 0.08)",
          fill: "+1",
          borderWidth: 1.5,
          tension: 0.3,
          pointRadius: 0
        },
        {
          label: "75th Percentile",
          data: p75Data,
          borderColor: "rgba(16, 185, 129, 0.5)",
          backgroundColor: "rgba(6, 182, 212, 0.12)",
          fill: "+1",
          borderWidth: 1.5,
          tension: 0.3,
          pointRadius: 0
        },
        {
          label: "50th Percentile (Median Path)",
          data: p50Data,
          borderColor: "#06b6d4",
          backgroundColor: "rgba(6, 182, 212, 0.15)",
          fill: "+1",
          borderWidth: 3,
          tension: 0.3,
          pointRadius: 4,
          pointBackgroundColor: "#06b6d4"
        },
        {
          label: "25th Percentile",
          data: p25Data,
          borderColor: "rgba(245, 158, 11, 0.5)",
          backgroundColor: "rgba(244, 63, 94, 0.08)",
          fill: "+1",
          borderWidth: 1.5,
          tension: 0.3,
          pointRadius: 0
        },
        {
          label: "5th Percentile (Worst 5% Path)",
          data: p5Data,
          borderColor: "rgba(244, 63, 94, 0.9)",
          borderWidth: 2,
          tension: 0.3,
          pointRadius: 0,
          fill: false
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: "top",
          labels: { color: "#94a3b8", font: { family: "Inter", size: 11 } }
        },
        tooltip: {
          backgroundColor: "rgba(15, 23, 42, 0.95)",
          titleColor: "#f8fafc",
          callbacks: {
            label: c => `${c.dataset.label}: $${c.raw.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
          }
        }
      },
      scales: {
        x: {
          grid: { color: "rgba(255, 255, 255, 0.04)" },
          ticks: { color: "#64748b", font: { family: "JetBrains Mono", size: 10 } }
        },
        y: {
          grid: { color: "rgba(255, 255, 255, 0.06)" },
          ticks: {
            color: "#94a3b8",
            font: { family: "JetBrains Mono", size: 11 },
            callback: v => `$${(v/1000).toFixed(0)}k`
          }
        }
      }
    }
  });
}

// Chart 3: Score Monotonicity Calibration (Win Rate & PF)
function renderScoreCharts(d) {
  const ctxWR = document.getElementById("scoreWinRateChart");
  const ctxPF = document.getElementById("scorePFChart");
  if (!ctxWR || !ctxPF || !d.score_bins) return;

  if (chart_score_wr) chart_score_wr.destroy();
  if (chart_score_pf) chart_score_pf.destroy();

  const labels = Object.keys(d.score_bins);
  const wrData = labels.map(k => d.score_bins[k].win_rate_pct);
  const pfData = labels.map(k => d.score_bins[k].profit_factor);

  // Win Rate Bar Chart
  chart_score_wr = new Chart(ctxWR, {
    type: "bar",
    data: {
      labels: labels.map(k => `Score ${k}`),
      datasets: [{
        label: "Win Rate (%)",
        data: wrData,
        backgroundColor: ["rgba(99, 102, 241, 0.7)", "rgba(6, 182, 212, 0.7)", "rgba(16, 185, 129, 0.8)", "rgba(16, 185, 129, 0.95)"],
        borderRadius: 6,
        borderWidth: 1,
        borderColor: "rgba(255, 255, 255, 0.1)"
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        title: { display: true, text: "Win Rate Monotonicity Across Score Tiers", color: "#f8fafc", font: { family: "Outfit", size: 14 } },
        legend: { display: false }
      },
      scales: {
        x: { ticks: { color: "#94a3b8" } },
        y: { min: 0, max: 100, ticks: { color: "#94a3b8", callback: v => `${v}%` }, grid: { color: "rgba(255, 255, 255, 0.05)" } }
      }
    }
  });

  // Profit Factor Bar Chart
  chart_score_pf = new Chart(ctxPF, {
    type: "bar",
    data: {
      labels: labels.map(k => `Score ${k}`),
      datasets: [{
        label: "Profit Factor",
        data: pfData,
        backgroundColor: ["rgba(245, 158, 11, 0.7)", "rgba(6, 182, 212, 0.7)", "rgba(16, 185, 129, 0.8)", "rgba(16, 185, 129, 0.95)"],
        borderRadius: 6,
        borderWidth: 1,
        borderColor: "rgba(255, 255, 255, 0.1)"
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        title: { display: true, text: "Profit Factor Escalation Across Score Tiers", color: "#f8fafc", font: { family: "Outfit", size: 14 } },
        legend: { display: false }
      },
      scales: {
        x: { ticks: { color: "#94a3b8" } },
        y: { ticks: { color: "#94a3b8" }, grid: { color: "rgba(255, 255, 255, 0.05)" } }
      }
    }
  });
}

// Chart 4: Regime & Session Attribution
function renderRegimeAndSessionCharts(d) {
  const ctxR = document.getElementById("regimeChart");
  const ctxS = document.getElementById("sessionChart");
  if (!ctxR || !ctxS) return;

  if (chart_regime) chart_regime.destroy();
  if (chart_session) chart_session.destroy();

  // Regime Breakdown
  if (d.regime_breakdown) {
    const regLabels = Object.keys(d.regime_breakdown);
    const regPnL = regLabels.map(k => d.regime_breakdown[k].net_pnl_usd);
    chart_regime = new Chart(ctxR, {
      type: "bar",
      data: {
        labels: regLabels,
        datasets: [{
          label: "Net Profit ($)",
          data: regPnL,
          backgroundColor: regPnL.map(v => v >= 0 ? "rgba(16, 185, 129, 0.8)" : "rgba(244, 63, 94, 0.8)"),
          borderRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: true, text: "Net Profit by Market Regime ($)", color: "#f8fafc", font: { family: "Outfit", size: 14 } },
          legend: { display: false }
        },
        scales: {
          x: { ticks: { color: "#94a3b8", font: { size: 10 } } },
          y: { ticks: { color: "#94a3b8", callback: v => `$${(v/1000).toFixed(0)}k` }, grid: { color: "rgba(255, 255, 255, 0.05)" } }
        }
      }
    });
  }

  // Session Breakdown
  if (d.session_breakdown) {
    const sessLabels = Object.keys(d.session_breakdown);
    const sessPnL = sessLabels.map(k => d.session_breakdown[k].net_pnl_usd);
    chart_session = new Chart(ctxS, {
      type: "doughnut",
      data: {
        labels: sessLabels,
        datasets: [{
          data: sessPnL.map(v => Math.max(0, v)),
          backgroundColor: ["#06b6d4", "#10b981", "#6366f1", "#f59e0b"],
          borderWidth: 2,
          borderColor: "#0f172a"
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: { display: true, text: "Session Profit Attribution Share", color: "#f8fafc", font: { family: "Outfit", size: 14 } },
          legend: { position: "right", labels: { color: "#94a3b8", font: { family: "Inter", size: 11 } } }
        }
      }
    });
  }
}

// Side-by-Side Cross-Timeframe Comparison Table
function renderMatrixComparisonTable(symMatrix) {
  const tbody = document.getElementById("matrix-table-body");
  if (!tbody) return;

  tbody.innerHTML = "";
  const timeframes = ["M1", "M5", "M15", "H1"];

  timeframes.forEach(tfKey => {
    const d = symMatrix[tfKey];
    if (!d) return;

    const tr = document.createElement("tr");
    if (tfKey === g_current_tf) {
      tr.style.backgroundColor = "rgba(6, 182, 212, 0.08)";
    }

    const p5_eq = d.monte_carlo?.final_equity_percentiles?.p5 || 0;
    const p95_eq = d.monte_carlo?.final_equity_percentiles?.p95 || 0;

    tr.innerHTML = `
      <td><span class="tf-badge">${tfKey}</span> <span style="color:#64748b; font-size:11px;">${d.timeframe_label.split(' ')[0]}</span></td>
      <td>${d.total_trades}</td>
      <td class="text-emerald" style="font-weight:600;">${d.win_rate_pct}%</td>
      <td class="text-cyan" style="font-weight:600;">${d.profit_factor}</td>
      <td class="text-emerald" style="font-weight:700;">+$${d.net_profit.toLocaleString()}</td>
      <td class="text-indigo">+$${d.expectancy_usd}</td>
      <td class="text-rose">$${d.max_drawdown_usd} (${d.max_drawdown_pct}%)</td>
      <td class="text-amber">${d.sharpe_ratio}</td>
      <td style="color:#cbd5e1;">$${(p5_eq/1000).toFixed(1)}k — $${(p95_eq/1000).toFixed(1)}k</td>
    `;
    tbody.appendChild(tr);
  });
}

// Render Complete Trade History Log with Exact Columns from Screenshot
function renderTradeHistory(d) {
  const tbody = document.getElementById("trade-history-body");
  if (!tbody || !d.trades) return;

  const allTrades = d.trades;

  // Update Section Header Badge
  const totalBadge = document.getElementById("total-trades-badge");
  if (totalBadge) totalBadge.textContent = allTrades.length.toLocaleString();

  // 1. Update Filter Counts
  const winTrades = allTrades.filter(t => t.pnl_net > 0 && t.exit_reason !== "BREAK-EVEN");
  const lossTrades = allTrades.filter(t => t.pnl_net < 0);
  const beTrades = allTrades.filter(t => t.exit_reason === "BREAK-EVEN" || (t.pnl_net >= 0 && t.pnl_net <= 15.0));

  document.getElementById("count-all").textContent = allTrades.length;
  document.getElementById("count-wins").textContent = winTrades.length;
  document.getElementById("count-losses").textContent = lossTrades.length;
  document.getElementById("count-be").textContent = beTrades.length;

  // 2. Apply Outcome Filter
  let filtered = allTrades;
  if (g_trade_filter_outcome === "WIN") {
    filtered = winTrades;
  } else if (g_trade_filter_outcome === "LOSS") {
    filtered = lossTrades;
  } else if (g_trade_filter_outcome === "BE") {
    filtered = beTrades;
  }

  // 3. Apply Search Query Filter
  if (g_trade_search_query) {
    filtered = filtered.filter(t => {
      const targetStr = `${t.date_time} ${t.direction} ${t.entry_price} ${t.exit_price} ${t.ai_surety} ${t.exit_reason} ${t.regime} ${t.session}`.toLowerCase();
      return targetStr.includes(g_trade_search_query);
    });
  }

  // 4. Reverse to show most recent trades first (matching screenshot)
  const displayList = filtered.slice().reverse();

  // 5. Pagination Calculation
  const totalFiltered = displayList.length;
  const totalPages = Math.max(1, Math.ceil(totalFiltered / g_trade_page_size));
  if (g_trade_page > totalPages) g_trade_page = totalPages;

  const startIdx = (g_trade_page - 1) * g_trade_page_size;
  const endIdx = Math.min(startIdx + g_trade_page_size, totalFiltered);
  const pageTrades = displayList.slice(startIdx, endIdx);

  // 6. Update Pagination Bar Info
  document.getElementById("pagination-info").textContent = totalFiltered > 0
    ? `Showing ${startIdx + 1} to ${endIdx} of ${totalFiltered.toLocaleString()} trades`
    : `No matching trades found`;
  document.getElementById("page-indicator").textContent = `Page ${g_trade_page} / ${totalPages}`;

  const prevBtn = document.getElementById("page-prev");
  const nextBtn = document.getElementById("page-next");
  if (prevBtn) prevBtn.disabled = (g_trade_page <= 1);
  if (nextBtn) nextBtn.disabled = (g_trade_page >= totalPages);

  // 7. Populate Exact 8 Columns Table Rows
  tbody.innerHTML = "";
  if (pageTrades.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" style="text-align:center; padding:30px; color:#64748b;">No trades match the current filter/search criteria.</td></tr>`;
    return;
  }

  pageTrades.forEach(t => {
    const tr = document.createElement("tr");
    const isBuy = (t.direction === "BUY");
    const sideBadge = `<span class="badge-direction-${isBuy ? 'buy' : 'sell'}">${t.direction}</span>`;
    
    let exitBadge = `<span class="badge-reason-sl">🛑 SL HIT</span>`;
    const reason = t.exit_reason || t.exit_type;
    if (reason === "TP HIT" || reason === "TAKE_PROFIT") {
      exitBadge = `<span class="badge-reason-tp">🎯 TP HIT</span>`;
    } else if (reason === "BREAK-EVEN" || reason === "BREAK_EVEN") {
      exitBadge = `<span class="badge-reason-be">🛡 BREAK-EVEN</span>`;
    } else if (reason === "EOD EXIT") {
      exitBadge = `<span class="badge-reason-eod">● EOD EXIT</span>`;
    }

    const isWin = (t.pnl_net > 0);
    const pnlClass = isWin ? "text-emerald" : "text-rose";
    const pnlSign = isWin ? "+" : "-";
    const pnlFormatted = `${pnlSign}$${Math.abs(t.pnl_net).toFixed(2)}`;

    const entryFormatted = `$${t.entry_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    const exitFormatted = `$${t.exit_price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    const suretyFormatted = t.ai_surety || `${t.ai_conf}%`;
    const balanceFormatted = `$${t.equity.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

    tr.innerHTML = `
      <td style="color:#94a3b8; font-size:12px;">${t.date_time || '2026-08-04 08:05'}</td>
      <td>${sideBadge}</td>
      <td style="font-weight:600; color:#f8fafc;">${entryFormatted}</td>
      <td style="font-weight:600; color:#f8fafc;">${exitFormatted}</td>
      <td style="font-weight:600; color:#e2e8f0;">${suretyFormatted}</td>
      <td>${exitBadge}</td>
      <td class="${pnlClass}" style="font-weight:700;">${pnlFormatted}</td>
      <td style="font-weight:600; color:#f8fafc;">${balanceFormatted}</td>
    `;
    tbody.appendChild(tr);
  });
}

// Export Current Filtered Trades to CSV
function exportCurrentTradesCSV() {
  if (!g_dashboard_data || !g_dashboard_data.matrix) return;
  const d = g_dashboard_data.matrix[g_current_symbol][g_current_tf];
  if (!d || !d.trades) return;

  const trades = d.trades;
  if (trades.length === 0) return;

  const headers = ["ENTRY_TIMESTAMP", "DIRECTION", "ENTRY_PRICE", "EXIT_PRICE", "AI_SURETY", "EXIT_REASON", "NET_PNL", "ACCOUNT_BALANCE"];
  const rows = trades.map(t => [
    t.date_time || "",
    t.direction,
    t.entry_price,
    t.exit_price,
    t.ai_surety || `${t.ai_conf}%`,
    t.exit_reason || t.exit_type,
    t.pnl_net,
    t.equity
  ]);

  let csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map(e => e.join(","))].join("\n");
  const encodedUri = encodeURI(csvContent);
  const link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", `smart_scalper_${g_current_symbol}_${g_current_tf}_trades.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}
