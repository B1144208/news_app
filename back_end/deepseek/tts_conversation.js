import fs from "fs";
import fetch from "node-fetch";
import dotenv from "dotenv";
import { exec } from "child_process";

dotenv.config();

const apiKey = process.env.ELEVENLABS_API_KEY;
if (!apiKey) throw new Error("ELEVENLABS_API_KEY is missing");

// 角色配置
const characters = {
  Alice: "21m00Tcm4TlvDq8ikWAM", // voice_id A
  Bob:   "AZnzlk1XvdvUeBnXmlld"  // voice_id B
};

// 對話腳本
const dialogue = [
  { speaker: "Alice", text: "哈囉，我是 Alice，很高興認識你！" },
  { speaker: "Bob",   text: "嗨 Alice，我是 Bob，今天過得如何？" },
  { speaker: "Alice", text: "我很好，謝謝你的關心。" }
];

async function generateSpeech(voiceId, text, outFile) {
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

  const payload = {
    text,
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
