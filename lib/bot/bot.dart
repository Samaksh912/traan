import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';



class FakeCallScreen extends StatefulWidget {
  @override
  _FakeCallScreenState createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool isCalling = false;
  AudioPlayer audioPlayer = AudioPlayer();
  String selectedLanguage = 'English';

  void startFakeCall() async {
    setState(() {
      isCalling = true;
    });
    await Future.delayed(Duration(seconds: 3)); // Simulate call delay
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => IncomingCallScreen(audioPlayer, selectedLanguage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Traan – Women Safety')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<String>(
              value: selectedLanguage,
              items: ['English', 'Hindi', 'Telugu', 'Tamil'].map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(language),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLanguage = newValue!;
                });
              },
            ),
            ElevatedButton(
              onPressed: startFakeCall,
              child: Text('Trigger Fake Call'),
            ),
          ],
        ),
      ),
    );
  }
}

class IncomingCallScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String selectedLanguage;
  IncomingCallScreen(this.audioPlayer, this.selectedLanguage);

  void answerCall(BuildContext context) async {
    String audioFile = selectedLanguage == 'Hindi' ? 'male_voice_hindi.mp3' :
    selectedLanguage == 'Telugu' ? 'male_voice_telugu.mp3' :
    selectedLanguage == 'Tamil' ? 'male_voice_tamil.mp3' :
    'male_voice.mp3';

    await audioPlayer.play(AssetSource(audioFile));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CallOngoingScreen(audioPlayer, selectedLanguage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Incoming Call...', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => answerCall(context),
              child: Text('Answer'),
            ),
          ],
        ),
      ),
    );
  }
}

class CallOngoingScreen extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String selectedLanguage;
  CallOngoingScreen(this.audioPlayer, this.selectedLanguage);

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, String>> dialogues = {
      'English': {
        'voice': '"Hey, where are you? I’m coming to pick you up!"',
        'response': '"I’m near XYZ place, please reach in 5 minutes."'
      },
      'Hindi': {
        'voice': '"अरे, तुम कहाँ हो? मैं तुम्हें लेने आ रहा हूँ!"',
        'response': '"मैं XYZ जगह पर हूँ, कृपया 5 मिनट में पहुंचें।"'
      },
      'Telugu': {
        'voice': '"హే, నువ్వు ఎక్కడ ఉన్నావు? నేను నిన్ను తీసుకురావటానికి వస్తున్నాను!"',
        'response': '"నేను XYZ ప్రాంతంలో ఉన్నాను, దయచేసి 5 నిమిషాల్లో రా."'
      },
      'Tamil': {
        'voice': '"ஹே, நீங்க எங்கே இருக்கீங்க? நான் உங்களை அழைத்துக்கொள்ள வருகிறேன்!"',
        'response': '"நான் XYZ இடத்தில் இருக்கிறேன், 5 நிமிடங்களில் அடையுங்கள்."'
      },
    };

    return Scaffold(
      appBar: AppBar(title: Text('Fake Call Ongoing')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Male Voice: ${dialogues[selectedLanguage]!['voice']}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Suggested Response: ${dialogues[selectedLanguage]!['response']}',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              audioPlayer.stop();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: Text('End Call'),
          ),
        ],
      ),
    );
  }
}