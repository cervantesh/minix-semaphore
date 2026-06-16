import http from "node:http";

const port = Number(process.env.PORT || 8080);
const bucketName = process.env.RESULT_BUCKET;
const objectName = process.env.RESULT_OBJECT || "runs/latest/result.json";

async function metadataToken() {
  const response = await fetch(
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
    { headers: { "Metadata-Flavor": "Google" } }
  );

  if (!response.ok) {
    throw new Error(`metadata token request failed: ${response.status}`);
  }

  const token = await response.json();
  return token.access_token;
}

async function loadResult() {
  if (!bucketName) {
    return {
      status: "not_configured",
      message: "RESULT_BUCKET is not set"
    };
  }

  const token = await metadataToken();
  const objectPath = encodeURIComponent(objectName);
  const url = `https://storage.googleapis.com/storage/v1/b/${bucketName}/o/${objectPath}?alt=media`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` }
  });

  if (!response.ok) {
    throw new Error(`result object request failed: ${response.status}`);
  }

  return response.json();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function html(result) {
  const status = result.status || "unknown";
  const passed = status === "passed";
  const artifactLinks = result.artifacts || {};
  const rawResult = escapeHtml(JSON.stringify(result, null, 2));

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>MINIX Semaphore Runner</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #f7f7f5; color: #161616; }
    main { max-width: 880px; margin: 0 auto; padding: 48px 24px; }
    h1 { font-size: 34px; margin: 0 0 12px; }
    .status { display: inline-flex; align-items: center; padding: 6px 10px; border-radius: 6px; font-weight: 700; background: ${passed ? "#dff4e8" : "#fde6df"}; color: ${passed ? "#146c43" : "#9a3412"}; }
    dl { display: grid; grid-template-columns: 160px 1fr; gap: 12px 18px; margin-top: 28px; }
    dt { font-weight: 700; color: #555; }
    dd { margin: 0; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; overflow-wrap: anywhere; }
    a { color: #185abc; }
    section { margin-top: 32px; }
    pre { background: #1f2937; color: #f8fafc; padding: 16px; border-radius: 6px; overflow: auto; }
  </style>
</head>
<body>
  <main>
    <h1>MINIX PM Semaphore Validation</h1>
    <span class="status">${escapeHtml(status)}</span>
    <dl>
      <dt>Commit</dt><dd>${escapeHtml(result.commit || "unknown")}</dd>
      <dt>Base</dt><dd>${escapeHtml(result.base || "unknown")}</dd>
      <dt>Test</dt><dd>${escapeHtml(result.test || "95")}</dd>
      <dt>Build Exit</dt><dd>${escapeHtml(result.buildExitCode ?? "unknown")}</dd>
      <dt>Test Exit</dt><dd>${escapeHtml(result.testExitCode ?? "unknown")}</dd>
      <dt>Started</dt><dd>${escapeHtml(result.startedAt || "unknown")}</dd>
      <dt>Finished</dt><dd>${escapeHtml(result.finishedAt || "unknown")}</dd>
    </dl>
    <section>
      <h2>Artifacts</h2>
      <ul>
        <li>Build log: ${escapeHtml(artifactLinks.buildLog || "not available")}</li>
        <li>Test log: ${escapeHtml(artifactLinks.testLog || "not available")}</li>
        <li>Serial log: ${escapeHtml(artifactLinks.serialLog || "not available")}</li>
      </ul>
    </section>
    <section>
      <h2>Raw Result</h2>
      <pre>${rawResult}</pre>
    </section>
  </main>
</body>
</html>`;
}

const server = http.createServer(async (req, res) => {
  try {
    const result = await loadResult();

    if (req.url === "/result.json") {
      res.writeHead(200, { "content-type": "application/json; charset=utf-8" });
      res.end(JSON.stringify(result, null, 2));
      return;
    }

    res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    res.end(html(result));
  } catch (error) {
    const body = {
      status: "error",
      message: error instanceof Error ? error.message : String(error)
    };

    res.writeHead(500, { "content-type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(body, null, 2));
  }
});

server.listen(port, () => {
  console.log(`MINIX runner status app listening on ${port}`);
});
