use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::Manager;

pub struct MetricsState(Mutex<Vec<MetricEvent>>);

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricEvent {
    pub event_type: String,
    pub session_id: String,
    pub strategy: String,
    pub timestamp: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub turn_number: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop_reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub success: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cost_usd: Option<f64>,
}

impl MetricEvent {
    pub fn new(event_type: &str, session_id: &str, strategy: &str) -> Self {
        Self {
            event_type: event_type.to_string(),
            session_id: session_id.to_string(),
            strategy: strategy.to_string(),
            timestamp: chrono_now_ms(),
            turn_number: None,
            stop_reason: None,
            tool_name: None,
            duration_ms: None,
            success: None,
            cost_usd: None,
        }
    }
}

fn chrono_now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

#[tauri::command]
pub fn get_metrics(
    state: tauri::State<'_, MetricsState>,
    event_type: Option<String>,
) -> Result<Vec<MetricEvent>, String> {
    let guard = state.0.lock().map_err(|e| format!("Lock error: {}", e))?;

    let events = guard.clone();

    let filtered = if let Some(et) = event_type {
        events.into_iter().filter(|e| e.event_type == et).collect()
    } else {
        events
    };

    let recent: Vec<_> = filtered.into_iter().rev().take(1000).collect();
    Ok(recent)
}

#[tauri::command]
pub fn clear_metrics(state: tauri::State<'_, MetricsState>) -> Result<(), String> {
    let mut guard = state.0.lock().map_err(|e| format!("Lock error: {}", e))?;
    guard.clear();
    Ok(())
}

pub fn init_metrics() -> MetricsState {
    MetricsState(Mutex::new(Vec::with_capacity(10_000)))
}
