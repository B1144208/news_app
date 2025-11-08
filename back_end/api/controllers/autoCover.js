import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
const s3 = new S3Client({ region: 'ap-northeast-1' });

await s3.send(new PutObjectCommand({
  Bucket: 'your-bucket',
  Key: 'latest.json',
  Body: Buffer.from(JSON.stringify(data)),
  ContentType: 'application/json',
  CacheControl: 'max-age=86400, stale-while-revalidate=60',
}));