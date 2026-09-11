const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const fetch = require("node-fetch");

// Secret Manager에서 OWM API 키를 참조 (값 자체는 런타임에만 로드됨)
const owmApiKey = defineSecret("OWM_API_KEY");

/**
 * getWeatherForecast (callable)
 *
 * OWM 5-day/3-hour forecast를 프록시합니다.
 * 클라이언트는 API 키를 모르고, 서버만 Secret Manager에서 읽습니다.
 *
 * - enforceAppCheck: 유효한 App Check 토큰이 없는 요청(디컴파일·스크립트 호출)은
 *   함수 코드 실행 전에 거부됨 → 쿼터 도용·과금 공격 차단
 * - maxInstances: 폭주 시에도 인스턴스 수를 제한해 과금 상한을 만듦
 */
exports.getWeatherForecast = onCall(
  {
    secrets: [owmApiKey],
    region: "asia-northeast3",
    enforceAppCheck: true,
    maxInstances: 5,
  },
  async (request) => {
    const lat = Number(request.data?.lat);
    const lon = Number(request.data?.lon);
    if (
      !Number.isFinite(lat) || lat < -90 || lat > 90 ||
      !Number.isFinite(lon) || lon < -180 || lon > 180
    ) {
      throw new HttpsError("invalid-argument", "lat/lon must be valid coordinates");
    }

    try {
      const apiKey = owmApiKey.value();
      const owmUrl =
        `https://api.openweathermap.org/data/2.5/forecast` +
        `?lat=${lat}&lon=${lon}&appid=${apiKey}&units=metric&lang=kr`;

      const owmRes = await fetch(owmUrl);
      if (owmRes.status === 429) {
        throw new HttpsError("resource-exhausted", "weather api rate limit");
      }
      if (!owmRes.ok) {
        // 외부 API 오류 본문은 로그로만 남기고 클라이언트에는 일반화된 메시지 반환
        console.error("OWM error:", owmRes.status, await owmRes.text());
        throw new HttpsError("unavailable", "weather api error");
      }

      return JSON.parse(await owmRes.text());
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("OWM fetch error:", err);
      throw new HttpsError("internal", "internal server error");
    }
  }
);
