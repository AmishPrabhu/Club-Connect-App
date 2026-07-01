import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

import User from './models/User.js';
import Club from './models/Club.js';

async function run() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("Connected to DB.");

    const email = 'santosh.amish@walchandsangli.ac.in';
    const user = await User.findOne({ email });
    console.log("USER RECORD:\n", JSON.stringify(user, null, 2));

    const advisorClubs = await Club.find({ advisorEmail: email });
    console.log("ADVISOR CLUBS:\n", advisorClubs.map(c => ({ id: c._id, name: c.name, fullForm: c.fullForm, advisorEmail: c.advisorEmail })));

    const presidentClubs = await Club.find({ presidentEmail: email });
    console.log("PRESIDENT CLUBS:\n", presidentClubs.map(c => ({ id: c._id, name: c.name, fullForm: c.fullForm, presidentEmail: c.presidentEmail })));

    const secretaryClubs = await Club.find({ secretaryEmail: email });
    console.log("SECRETARY CLUBS:\n", secretaryClubs.map(c => ({ id: c._id, name: c.name, fullForm: c.fullForm, secretaryEmail: c.secretaryEmail })));

    const allClubs = await Club.find();
    console.log("ALL CLUBS IN DB:\n", allClubs.map(c => ({ id: c._id, name: c.name, fullForm: c.fullForm })));

    await mongoose.disconnect();
}

run().catch(console.error);
