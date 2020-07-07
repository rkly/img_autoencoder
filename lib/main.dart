import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:io';

void main() => runApp(App());

const String model = "ConvAutoencoder";

class App extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Tflite Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Image ConvAutoencoder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _busy = false;
  File _image;
  String _model = model;
  List _recognitions;

  @override
  void initState() {
    super.initState();

    _busy = true;

    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  Future predictImagePicker() async {
    final _picker = ImagePicker();
    PickedFile image = await _picker.getImage(source: ImageSource.camera);
    _image = File(image.path);
    if (_image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(_image);
  }

  Future predictImage(File image) async {
    if (image == null) return;
    await autoencodeImageBinary(image);
    setState(() {
      _image = image;
      _busy = false;
    });
  }

  Future autoencodeImageBinary(File image) async {
    int startTime = new DateTime.now().millisecondsSinceEpoch;
    /*var imageBytes = await readFileByte(image.path);
    img.Image origImage = img.decodeJpg(imageBytes);
    img.Image resizedImage = img.copyResize(origImage, height: 224, width: 224);
    var recognitions = await Tflite.runPix2PixOnBinary(
      binary: imageToByteListUint8(resizedImage, 224),
    );*/
    var recognitions = await Tflite.runPix2PixOnImage(path: image.path);
    setState(() {
      _recognitions = recognitions;
    });
    int endTime = new DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
  }

  Future<Uint8List> readFileByte(String filePath) async {
    Uri myUri = Uri.parse(filePath);
    File audioFile = new File.fromUri(myUri);
    Uint8List bytes;
    await audioFile.readAsBytes().then((value) {
      bytes = Uint8List.fromList(value);
      print('reading of bytes is completed');
    }).catchError((onError) {
      print('Exception Error while reading audio from path:' +
          onError.toString());
    });
    return bytes;
  }

  Uint8List imageToByteListUint8(img.Image image, int inputSize) {
    var convertedBytes = Uint8List(1 * inputSize * inputSize * 3 * 4);
    var buffer = Uint8List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = img.getRed(pixel);
        buffer[pixelIndex++] = img.getGreen(pixel);
        buffer[pixelIndex++] = img.getBlue(pixel);
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  /*Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
        buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
      }
    }
    print(convertedBytes.buffer.asUint8List().length);
    print(convertedBytes.buffer.asFloat32x4List().length);
    print(convertedBytes.buffer.asFloat32List().length);
    return convertedBytes.buffer.asUint8List();
  }*/

  Future loadModel() async {
    Tflite.close();
    try {
      String res;
      res = await Tflite.loadModel(model: "assets/convautoencoder.tflite");
      print(res);
    } on PlatformException {
      print("Failed to load the model.");
    }
  }

  onSelect(model) async {
    setState(() {
      _busy = true;
      _model = model;
      _recognitions = null;
    });
    await loadModel();
    
    if (_image != null) {
      predictImage(_image);
    } else {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    Size size = MediaQuery.of(context).size;

    if (_busy) {
      stackChildren.add(const Opacity(
        child: ModalBarrier(dismissible: false, color: Colors.grey),
        opacity: 0.3,
      ));
      stackChildren.add(const Center(child: CircularProgressIndicator()));
    }

    stackChildren.add(ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        Column(
          children: <Widget>[
            _image == null
                ? Text('No image selected.')
                : Image.file(File(_image.path)),
            Text(
              'Autoencoded Image:',
              textAlign: TextAlign.center,
            ),
            _recognitions == null
                ? Text('No image selected.')
                : Container(
                decoration: BoxDecoration(
                    image: DecorationImage(
                        alignment: Alignment.topCenter,
                        image: MemoryImage(_recognitions),
                        fit: BoxFit.fill)),
                child: Opacity(opacity: 0.3, child: Image.file(_image))),
          ],
        )
      ],
    ));


    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: onSelect,
            itemBuilder: (context) {
              List<PopupMenuEntry<String>> menuEntries = [
                const PopupMenuItem<String>(
                  child: Text("ConvAutoencoder"),
                  value: "ConvAutoencoder",
                )
              ];
              return menuEntries;
            },
          )
        ],
      ),
      body: Stack(
        children: stackChildren,
      ), // This trailing comma makes auto-formatting nicer for build methods.
      floatingActionButton: FloatingActionButton(
        onPressed: predictImagePicker,
        tooltip: 'Select Image',
        child: Icon(Icons.image),
      ),
    );
  }
}
