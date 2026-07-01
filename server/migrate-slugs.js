import mongoose from 'mongoose';
import dotenv from 'dotenv';
import slugify from 'slugify';
import Club from './models/Club.js';

dotenv.config();

mongoose.connect(process.env.MONGODB_URI)
    .then(async () => {
        console.log('Connected to MongoDB');
        const clubs = await Club.find({ slug: { $exists: false } });
        console.log(`Found ${clubs.length} clubs to migrate.`);

        for (const club of clubs) {
            const slug = slugify(club.name, { lower: true, strict: true });
            club.slug = slug;
            await club.save();
            console.log(`Migrated: ${club.name} -> ${slug}`);
        }

        console.log('Migration complete.');
        process.exit(0);
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
