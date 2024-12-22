import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';


class TranslationScreen extends StatefulWidget {
  const TranslationScreen({Key? key}) : super(key: key);

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final translator = GoogleTranslator();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isListening = false;
  bool _isTranslating = false;
  bool _isSpeaking = false;
  bool _isScanning = false;
  String _selectedSourceLanguage = 'en';
  String _selectedTargetLanguage = 'es';

  final Map<String, String> _languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTTS();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _initTTS() async {
    await _flutterTts.setLanguage(_selectedTargetLanguage);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _sourceController.text = result.recognizedWords;
            });
          },
          localeId: _selectedSourceLanguage,
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _translateText() async {
    if (_sourceController.text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      var translation = await translator.translate(
        _sourceController.text,
        from: _selectedSourceLanguage,
        to: _selectedTargetLanguage,
      );

      setState(() {
        _targetController.text = translation.text;
        _isTranslating = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation error: $e')),
      );
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _speakTranslatedText() async {
    if (_targetController.text.isEmpty) return;

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    await _flutterTts.setLanguage(_selectedTargetLanguage);
    setState(() => _isSpeaking = true);
    await _flutterTts.speak(_targetController.text);
  }

  Future<void> _scanImage() async {
    try {
      setState(() => _isScanning = true);

      final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera);
      if (image == null) {
        setState(() => _isScanning = false);
        return;
      }

      final File imageFile = File(image.path);
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage);

      if (recognizedText.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in image')),
        );
      } else {
        setState(() {
          _sourceController.text = recognizedText.text;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning text: $e')),
      );
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _pickAndScanImage() async {
    try {
      setState(() => _isScanning = true);

      final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery);
      if (image == null) {
        setState(() => _isScanning = false);
        return;
      }

      final File imageFile = File(image.path);
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage);

      if (recognizedText.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in image')),
        );
      } else {
        setState(() {
          _sourceController.text = recognizedText.text;
        });
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _sourceController.dispose();
    _targetController.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translator & Speech'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedSourceLanguage,
              isExpanded: true,
              items: _languages.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSourceLanguage = value);
                }
              },
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _sourceController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter text to translate...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),

                suffixIcon: IconButton(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButton<String>(
              value: _selectedTargetLanguage,
              isExpanded: true,
              items: _languages.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTargetLanguage = value);
                }
              },
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _targetController,
              maxLines: 4,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Translation will appear here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                  onPressed: _speakTranslatedText,
                ),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _translateText,
              icon: _isTranslating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.translate),
              label: Text(_isTranslating ? 'Translating...' : 'Translate'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}