/**
 * One-time migration: Set termYear = '2025-2026' and isCurrent = true
 * on ALL existing ClubMember documents that don't already have a termYear set.
 *
 * Run with:  node --experimental-vm-modules server/scripts/migrate_term_year.js
 * (from the project root), or:  node scripts/migrate_term_year.js  (from /server)
 */

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import path from 'path';

// Load .env from the server directory
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI;
if (!MONGO_URI) {
  console.error('❌  MONGO_URI not found in .env');
  process.exit(1);
}

const clubMemberSchema = new mongoose.Schema({}, { strict: false });
const ClubMember = mongoose.model('ClubMember', clubMemberSchema);

async function migrate() {
  await mongoose.connect(MONGO_URI);
  console.log('✅  Connected to MongoDB');

  // 1. Count total documents
  const total = await ClubMember.countDocuments();
  console.log(`📊  Total ClubMember documents: ${total}`);

  // 2. Update all docs that are missing or have a blank termYear
  const result = await ClubMember.updateMany(
    {
      $or: [
        { termYear: { $exists: false } },
        { termYear: '' },
        { termYear: null },
      ],
    },
    {
      $set: {
        termYear: '2025-2026',
        isCurrent: true,
      },
    }
  );

  console.log(`✏️   Updated ${result.modifiedCount} documents → termYear: '2025-2026', isCurrent: true`);

  // 3. Also ensure ALL existing docs have isCurrent: true (in case any got set to false by accident)
  const result2 = await ClubMember.updateMany(
    { termYear: '2025-2026', isCurrent: { $ne: true } },
    { $set: { isCurrent: true } }
  );
  console.log(`✏️   Fixed isCurrent on ${result2.modifiedCount} additional documents`);

  // 4. Summary
  const after = await ClubMember.countDocuments({ termYear: '2025-2026', isCurrent: true });
  console.log(`\n🎉  Done! ${after} / ${total} members are now in 2025-2026 active roster.`);

  await mongoose.disconnect();
  console.log('🔌  Disconnected.');
}

migrate().catch((err) => {
  console.error('❌  Migration failed:', err);
  process.exit(1);
});
