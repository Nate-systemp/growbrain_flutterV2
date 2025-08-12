# GrowBrain Firebase Database Structure

This document outlines the complete Firebase Firestore database structure for the GrowBrain Flutter application.

## Database Overview

The GrowBrain app uses Firebase Firestore as its primary database. The structure is organized around teachers who manage students and their gaming sessions.

## Collections Structure

### 1. `teachers` Collection

**Path**: `/teachers/{teacherId}`

Each teacher document contains basic teacher information and has subcollections for students.

#### Teacher Document Fields:
```json
{
  "email": "teacher@example.com",
  "fullName": "John Doe",
  "createdAt": "2024-01-15T10:30:00Z",
  "lastLogin": "2024-01-20T14:45:00Z"
}
```

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `email` | String | Teacher's email address | Yes |
| `fullName` | String | Teacher's full name | Yes |
| `createdAt` | Timestamp | Account creation date | Yes |
| `lastLogin` | Timestamp | Last login timestamp | No |

---

### 2. `students` Subcollection

**Path**: `/teachers/{teacherId}/students/{studentId}`

Each student document contains student information and their current session configuration.

#### Student Document Fields:
```json
{
  "fullName": "Jane Smith",
  "age": 8,
  "grade": "Grade 3",
  "createdAt": "2024-01-15T11:00:00Z",
  "lastPlayed": "2024-01-20T15:30:00Z",
  "session": [
    "Match Cards",
    "TicTacToe",
    "Who Moved?"
  ],
  "totalGamesPlayed": 25,
  "averageAccuracy": 78.5,
  "favoriteGame": "Match Cards"
}
```

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `fullName` | String | Student's full name | Yes |
| `age` | Number | Student's age | No |
| `grade` | String | Student's grade level | No |
| `createdAt` | Timestamp | Student record creation date | Yes |
| `lastPlayed` | Timestamp | Last game session timestamp | No |
| `session` | Array<String> | List of selected games for current session | No |
| `totalGamesPlayed` | Number | Total number of games completed | No |
| `averageAccuracy` | Number | Average accuracy across all games | No |
| `favoriteGame` | String | Most frequently played game | No |

---

### 3. `records` Subcollection

**Path**: `/teachers/{teacherId}/students/{studentId}/records/{recordId}`

Each record document represents a single game completion with performance metrics.

#### Record Document Fields:
```json
{
  "date": "2024-01-20T15:30:00Z",
  "challengeFocus": "Memory",
  "game": "Match Cards",
  "difficulty": "Easy",
  "accuracy": 85,
  "completionTime": 120,
  "lastPlayed": "Match Cards",
  "score": 850,
  "attempts": 3,
  "hintsUsed": 2,
  "sessionId": "session_20240120_001"
}
```

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `date` | Timestamp | Game completion timestamp | Yes |
| `challengeFocus` | String | Category of cognitive challenge | Yes |
| `game` | String | Name of the game played | Yes |
| `difficulty` | String | Difficulty level (Easy/Medium/Hard) | Yes |
| `accuracy` | Number | Accuracy percentage (0-100) | Yes |
| `completionTime` | Number | Time taken to complete (seconds) | Yes |
| `lastPlayed` | String | Last game played in session | Yes |
| `score` | Number | Game score achieved | No |
| `attempts` | Number | Number of attempts made | No |
| `hintsUsed` | Number | Number of hints used | No |
| `sessionId` | String | Session identifier for grouping | No |

---

## Game Categories and Types

### Challenge Focus Categories:
- **Attention**: Focus and concentration games
- **Verbal**: Language and communication games  
- **Memory**: Memory and recall games
- **Logic**: Problem-solving and reasoning games

### Available Games by Category:

#### Attention Games:
- `Who Moved?` - Object position memory game
- `Light Tap` - Reaction time and focus game
- `Find Me` - Visual search and attention game

#### Verbal Games:
- `Sound Match` - Audio recognition game
- `Rhyme Time` - Rhyming and phonics game
- `Picture Words` - Vocabulary and word association game

#### Memory Games:
- `Match Cards` - Card matching memory game
- `Fruit Shuffle` - Sequence memory game
- `Object Hunt` - Visual memory game

#### Logic Games:
- `Puzzle` - Problem-solving puzzle game
- `TicTacToe` - Strategic thinking game
- `Riddle Game` - Logic and reasoning game

### Difficulty Levels:
- `Easy` (Display: "Starter") - Perfect for beginners
- `Medium` (Display: "Growing") - Good for developing skills  
- `Hard` (Display: "Challenged") - For advanced learners

---

## Data Relationships

```
teachers (collection)
├── {teacherId} (document)
│   ├── email: string
│   ├── fullName: string
│   ├── createdAt: timestamp
│   └── students (subcollection)
│       ├── {studentId} (document)
│       │   ├── fullName: string
│       │   ├── age: number
│       │   ├── session: array
│       │   └── records (subcollection)
│       │       └── {recordId} (document)
│       │           ├── date: timestamp
│       │           ├── game: string
│       │           ├── difficulty: string
│       │           ├── accuracy: number
│       │           └── completionTime: number
│       └── {studentId2} (document)
└── {teacherId2} (document)
```

---

## Security Rules

The database should implement the following security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Teachers can only access their own data
    match /teachers/{teacherId} {
      allow read, write: if request.auth != null && request.auth.uid == teacherId;
      
      // Students subcollection
      match /students/{studentId} {
        allow read, write: if request.auth != null && request.auth.uid == teacherId;
        
        // Records subcollection
        match /records/{recordId} {
          allow read, write: if request.auth != null && request.auth.uid == teacherId;
        }
      }
    }
  }
}
```

---

## Indexes

Recommended composite indexes for optimal query performance:

### Students Collection:
- `createdAt` (Descending)
- `lastPlayed` (Descending)
- `totalGamesPlayed` (Descending)

### Records Collection:
- `date` (Descending)
- `challengeFocus` + `date` (Descending)
- `game` + `date` (Descending)
- `difficulty` + `date` (Descending)
- `accuracy` (Descending)
- `completionTime` (Ascending)

---

## Sample Queries

### Get all students for a teacher:
```dart
FirebaseFirestore.instance
  .collection('teachers')
  .doc(teacherId)
  .collection('students')
  .orderBy('createdAt', descending: true)
  .get()
```

### Get student's game records:
```dart
FirebaseFirestore.instance
  .collection('teachers')
  .doc(teacherId)
  .collection('students')
  .doc(studentId)
  .collection('records')
  .orderBy('date', descending: true)
  .limit(50)
  .get()
```

### Get records by game type:
```dart
FirebaseFirestore.instance
  .collection('teachers')
  .doc(teacherId)
  .collection('students')
  .doc(studentId)
  .collection('records')
  .where('game', isEqualTo: 'Match Cards')
  .orderBy('date', descending: true)
  .get()
```

### Get records by challenge focus:
```dart
FirebaseFirestore.instance
  .collection('teachers')
  .doc(teacherId)
  .collection('students')
  .doc(studentId)
  .collection('records')
  .where('challengeFocus', isEqualTo: 'Memory')
  .orderBy('date', descending: true)
  .get()
```

---

## Data Export Structure

For website integration, data can be exported in the following JSON structure:

```json
{
  "teachers": {
    "teacherId1": {
      "email": "teacher1@example.com",
      "fullName": "John Doe",
      "students": {
        "studentId1": {
          "fullName": "Jane Smith",
          "age": 8,
          "session": ["Match Cards", "TicTacToe"],
          "records": {
            "recordId1": {
              "date": "2024-01-20T15:30:00Z",
              "game": "Match Cards",
              "difficulty": "Easy",
              "accuracy": 85,
              "completionTime": 120
            }
          }
        }
      }
    }
  }
}
```

---

## Migration Notes

When connecting to a website:

1. **Authentication**: Ensure Firebase Auth is configured for web
2. **CORS**: Configure Firebase for web domain access
3. **API Keys**: Set up separate web API keys if needed
4. **Real-time Updates**: Use Firestore real-time listeners for live data
5. **Offline Support**: Consider Firestore offline persistence for web

---

## Performance Considerations

1. **Pagination**: Implement pagination for large record sets
2. **Caching**: Use appropriate caching strategies for frequently accessed data
3. **Batch Operations**: Use batch writes for multiple record updates
4. **Connection Pooling**: Optimize connection usage for web applications
5. **Data Aggregation**: Consider pre-computed aggregations for analytics

---

*Last Updated: January 2024*
*Version: 1.0*