import fs from "fs";
import fetch from "node-fetch";
import dotenv from "dotenv";
import { exec } from "child_process";

dotenv.config();

const apiKey = process.env.ELEVENLABS_API_KEY;
if (!apiKey) throw new Error("ELEVENLABS_API_KEY is missing");

// 角色配置
const characters = {
  ask: "9lHjugDhwqoxA5MhX0az",
  ans:   "fQj4gJSexpu8RDE2Ii5m"
};

// 對話腳本
const dialogue = [
  { speaker: "ask", text: "根據最新報導，8月底發生的「走讀活動」導致了警民衝突，8名警員受傷。那麼，事件的主要經過是怎樣的呢？" },
  { speaker: "ans",   text: "事件發生於8月30日，民眾黨主席黃國昌號召支持者小草舉行了一場名為「走讀」的集會遊行活動，結果引發了警方和市民之間的衝突。" },
  { speaker: "ask", text: "在這場衝突中，有哪些人或事引起了注意？黃國昌是否涉及其中的關鍵罪名？" },
  { speaker: "ans", text: "是的，黃國昌涉嫌違反了《集會遊行法》和《聚眾妨害公務法》，並且可能還有個資法的問題。警方已經注意到這些情況，並於9月2日向黃國昌及其他三人發出了到案說明的通知。" },
  { speaker: "ask", text: "根據北市中正一分局的說法，他們通知黃國昌明天來案，但具體時間沒有確定，如果他不來，將直接送北檢處理。那麼，目前的情況是怎麼樣的呢？" },
  { speaker: "ans", text: "對的，到目前為止，另外兩名嫌犯仍未與警方聯繫。我們注意到，黃國昌在衝突中涉嫌勒警員脖子，這可能是為什麼警方會關注他的原因。" },
  { speaker: "ask", text: "除了到案說明的通知外，還有哪些動作顯示了警方正在努力應對這場危機？例如，是否有增派人手的跡象？" },
  { speaker: "ans", text: "是的，為了回應這次庭審，北院可能會增派40名警力，這在即將開庭的一天會有備用警力。" },
  { speaker: "ask", text: "最後，黃國昌及其團隊面臨的風險有哪些？如果他無法履行到案說明的責任，他們將面臨怎樣的後果？" },
  { speaker: "ans", text: "是的，在這種情況下，警方會直接將案件移送北檢機關處理。我們相信，法律會給出一個公正的結果，希望黃國昌能盡快出面接受調查。" }
];

async function generateSpeech(voiceId, text, outFile) {
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

  const payload = {
    text,
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

  const file = fs.createWriteStream(outFile);
  await new Promise((resolve, reject) => {
    res.body.pipe(file);
    res.body.on("error", reject);
    file.on("finish", resolve);
  });
}

async function mergeAudio(files, outputFile) {
  const listFile = "file_list.txt";
  const listContent = files.map(f => `file '${f}'`).join("\n");
  fs.writeFileSync(listFile, listContent);

  return new Promise((resolve, reject) => {
    exec(`ffmpeg -y -f concat -safe 0 -i ${listFile} -c copy ${outputFile}`, (err) => {
      fs.unlinkSync(listFile);
      if (err) reject(err);
      else resolve();
    });
  });
}

async function main() {
  const tempFiles = [];

  for (let i = 0; i < dialogue.length; i++) {
    const { speaker, text } = dialogue[i];
    const voiceId = characters[speaker];
    if (!voiceId) throw new Error(`No voiceId for ${speaker}`);
    const tempFile = `temp_${i + 1}.mp3`;
    await generateSpeech(voiceId, text, tempFile);
    tempFiles.push(tempFile);
  }

  await mergeAudio(tempFiles, "conversation.mp3");
  console.log("Saved conversation.mp3");

  // 刪除暫存檔
  for (const f of tempFiles) {
    fs.unlinkSync(f);
  }
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
