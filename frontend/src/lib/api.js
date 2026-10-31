const API_URL = import.meta.env.VITE_API_URL;

if (!API_URL) {
  throw new Error("VITE_API_URL is not configured");
}

async function apiRequest(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
  });

  if (!response.ok) {
    const errorBody = await response.text();

    throw new Error(
      `API request failed (${response.status}): ${errorBody}`
    );
  }

  return response.json();
}

export function getTelemetry(siteId = "building-01") {
  return apiRequest(
    `/telemetry?site_id=${encodeURIComponent(siteId)}`
  );
}

export function askAssistant(question, siteId = "building-01") {
  return apiRequest("/ask", {
    method: "POST",
    body: JSON.stringify({
      question,
      site_id: siteId,
    }),
  });
}

export function checkBackendHealth() {
  return apiRequest("/health");
}
