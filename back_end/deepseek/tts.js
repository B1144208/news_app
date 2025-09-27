import 'dotenv/config';
import fs from "fs";
import fetch from "node-fetch";

const apiKey = process.env.ELEVENLABS_API_KEY;
const voiceId = "21m00Tcm4TlvDq8ikWAM"; // 先用預設/常見聲音，或改成你查到的 voice_id
const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

async function main() {
  if (!apiKey) throw new Error("ELEVEN_API_KEY is missing");
  const payload = {
    text: "哈囉，這是一段 ElevenLabs 的測試音檔！",
    model_id: "eleven_multilingual_v2",
    voice_settings: { stability: 0.5, similarity_boost: 0.75 }
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