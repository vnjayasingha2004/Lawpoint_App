# LawPoint

LawPoint is a legal services platform with:
- client and lawyer accounts
- legal locker
- encrypted messaging
- knowledge hub
- appointment booking
- lawyer verification workflow

## Tech Stack
- Flutter
- Node.js / Express
- PostgreSQL

## Setup

### Backend
1. Copy `.env.example`to `.env`
2. Fill your local values
3. Install packages
4. Run the server

### Database
1. Create PostgreSQL database
2. Run `database/schema.sql`

3 . Delete everything from line 930 - 1099 if you doesnt create a user name lawpoint_user
4. comment down these lines 
     5,29,32,40,1106


### Flutter
1. `flutter pub get`
2. run the app
