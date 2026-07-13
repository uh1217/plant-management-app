const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const fetch = require("node-fetch");

// Secret Manager에서 OWM API 키를 참조 (값 자체는 런타임에만 로드됨)
const owmApiKey = defineSecret("OWM_API_KEY");

/**
 * GET /getWeatherForecast?lat={lat}&lon={lon}
 *
 * OWM 5-day/3-hour forecast를 프록시합니다.
 * 클라이언트는 API 키를 모르고, 서버만 Secret Manager에서 읽습니다.
 */
exports.getWeatherForecast = onRequest(
  { secrets: [owmApiKey], region: "asia-northeast3" },
  async (req, res) => {
    // CORS 허용 (Flutter 앱의 HTTP 요청 허용)
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "GET");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.status(204).send("");
      return;
    }

    const { lat, lon } = req.query;
    if (!lat || !lon) {
      res.status(400).json({ error: "lat and lon are required" });
      return;
    }

    try {
      const apiKey = owmApiKey.value();
      const owmUrl =
        `https://api.openweathermap.org/data/2.5/forecast` +
        `?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;

      const owmRes = await fetch(owmUrl);
      if (!owmRes.ok) {
        const body = await owmRes.text();
        res.status(owmRes.status).json({ error: body });
        return;
      }

      const data = await owmRes.json();
      res.status(200).json(data);
    } catch (err) {
      console.error("OWM fetch error:", err);
      res.status(500).json({ error: "internal server error" });
    }
  }
);
