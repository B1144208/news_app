import fs from "fs";
import fetch from "node-fetch";
import dotenv from "dotenv";

dotenv.config();

const apiKey = process.env.ELEVENLABS_API_KEY;
const voiceId = "21m00Tcm4TlvDq8ikWAM"; // dafault

const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

async function main() {
  if (!apiKey) throw new Error("ELEVENLABS_API_KEY is missing");
  const payload = {
    text: "開始為您播放今日焦點新聞，第一篇是快新聞，北市中正一警局下通牒　黃國昌明天未到案就送北檢偵辦，第二篇是快新聞／好可怕！台南警匪追逐戰　歹徒持榔頭攻擊員警、所長被咬傷，第三篇是青少年受情緒困擾 兒盟調查：逾2成想過輕生，第四篇是喝咖啡讓人更長壽？　營養師：每天3至5杯效果最佳，第五篇是腸病毒重症已奪8命！伊科11型來勢洶洶　疾管署：幼童是高風險族群。接下來是各篇新聞的大致內容：「走讀活動」引發警方與民眾對峙，8名警員受傷，而主嫌黃國昌涉嫌違反《集會遊行法》及《聚眾妨害公務法》。台北市警局已通知黃國昌明早到案說服，如果他不來將送北檢處理。",
    model_id: "eleven_multilingual_v2",
    voice_settings: { stability: 1, similarity_boost: 0.75 }
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey,
      "Content-Type": "application/json",
      "Accept": "audio/mpeg"
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`HTTP ${res.status} - ${errText}`);
  }

  const file = fs.createWriteStream("out.mp3");
  await new Promise((resolve, reject) => {
    res.body.pipe(file);
    res.body.on("error", reject);
    file.on("finish", resolve);
  });
  console.log("Saved to out.mp3");
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});