import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:math';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as location_dart;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();

  Hive.init(appDocumentDir.path);
  Hive.registerAdapter(TrackAdapter());
  Hive.registerAdapter(UserAdapter());
  await Hive.openBox<Track>('trackBox');
  await Hive.openBox<User>('userBox');

  bool firstStart = prefs.getBool("firstStart") ?? true;
  if (firstStart) {
    prefs.setBool("firstStart", false);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(prefs)),
        ChangeNotifierProvider(create: (_) => TrackList()),
        ChangeNotifierProvider(create: (_) => AuthCodeProvider()),
      ],
      child: MyApp(prefs: prefs, firstStart: firstStart),
    ),
  );
}

class AuthCodeProvider with ChangeNotifier {
  String _authCode = '';
  String get authCode => _authCode;

  void setAuthCode(String code) {
    _authCode = code;
  }
}

class AuthCodeScreen extends StatelessWidget {
  final SharedPreferences prefs;
  final bool firstStart;

  AuthCodeScreen({required this.prefs, required this.firstStart});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthCodeProvider(),
      child: AuthCodeWidget(prefs: prefs, firstStart: firstStart),
    );
  }
}

class AuthCodeWidget extends StatelessWidget {
  final SharedPreferences prefs;
  final bool firstStart;

  AuthCodeWidget({required this.prefs, required this.firstStart});

  String _generateCode() {
    String chars = "abcdefghijklmnopqrstuvwxyz";
    String digits = "0123456789";
    String randomCode = "";
    var random = Random();

    for (int i = 0; i < 3; i++) {
      randomCode += chars[random.nextInt(chars.length)];
    }

    for (int i = 0; i < 3; i++) {
      randomCode += digits[random.nextInt(digits.length)];
    }

    prefs.setString('authCode', randomCode);
    return randomCode;
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController codeController = TextEditingController();

    final authCodeProvider = Provider.of<AuthCodeProvider>(context, listen: true);

    late var authCode = prefs.getString("authCode");
    if(authCode == null){
      authCode = _generateCode();
      authCodeProvider.setAuthCode(authCode);
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Введите код авторизации",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              child: TextFormField(
                controller: codeController,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (authCode == codeController.text) {
                  Navigator.pushNamed(context, '/');
                }
              },
              child: Text("Проверить код"),
            ),
            SizedBox(height: 20),
            Visibility(
              visible: firstStart,
              child: Text(
                "Запомните этот код: \n" + authCode,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@HiveType(typeId: 1)
class User extends HiveObject {
  @HiveField(0)
  late String firstName;

  @HiveField(1)
  late String lastName;

  @HiveField(2)
  late String middleName;

  @HiveField(3)
  late String birthDate;

  @HiveField(4)
  late String? imagePath;

  @HiveField(5)
  late double? locationLatitude;

  @HiveField(6)
  late double? locationLongitude;

  User({
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.birthDate,
    required this.imagePath,
    required this.locationLatitude,
    required this.locationLongitude
  });
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final typeId = 1;

  @override
  User read(BinaryReader reader) {
    return User(
      firstName: reader.read(),
      lastName: reader.read(),
      middleName: reader.read(),
      birthDate: reader.read(),
      imagePath: reader.read(),
      locationLatitude: reader.read(),
      locationLongitude: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.write(obj.firstName);
    writer.write(obj.lastName);
    writer.write(obj.middleName);
    writer.write(obj.birthDate);
    writer.write(obj.imagePath);
    writer.write(obj.locationLatitude);
    writer.write(obj.locationLongitude);
  }
}


@HiveType(typeId: 0)
class Track {
  @HiveField(0)
  late String name;
  @HiveField(1)
  late String author;
  @HiveField(2)
  late String imageURL;
  @HiveField(3)
  late String downloadURL;

  Track({
    required this.name,
    required this.author,
    required this.imageURL,
    required this.downloadURL,
  });
}

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final typeId = 0;

  @override
  Track read(BinaryReader reader) {
    return Track(
      name: reader.read(),
      author: reader.read(),
      imageURL: reader.read(),
      downloadURL: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer.write(obj.name);
    writer.write(obj.author);
    writer.write(obj.imageURL);
    writer.write(obj.downloadURL);
  }
}

class TrackList with ChangeNotifier {
  late Box<Track> _trackBox;
  List<Track> get tracks => _trackBox.values.toList();

  TrackList() {
    _openBox();
    _trackBox = Hive.box<Track>('trackBox');
    if (_trackBox.isEmpty) {
      _trackBox.add(Track(
        name: "The Sun",
        author: "Myd feat. JAWNY",
        imageURL:
        "https://avatars.yandex.net/get-music-content/5531900/f7c55c48.a.21060561-1/1000x1000",
        downloadURL:
        "https://music.yandex.ru/album/21060561/track/100388660",
      ));
      _trackBox.add(Track(
        name: "Chemicals",
        author: "Besomorph, Neoni",
        imageURL:
        "https://avatars.yandex.net/get-music-content/5280749/fd7602da.a.18100253-2/1000x1000",
        downloadURL: "https://music.yandex.ru/album/18100253/track/91128238",
      ));
      _trackBox.add(Track(
        name: "Higher",
        author: "Lemaire, Maty Noyes, Jerry Folk",
        imageURL:
        "https://avatars.yandex.net/get-music-content/113160/5c19ba86.a.4659577-1/1000x1000",
        downloadURL: "https://music.yandex.ru/album/4659577/track/36906380",
      ));
      _trackBox.add(Track(
        name: "She`s on my mind",
        author: "JP Cooper",
        imageURL:
        "https://avatars.yandex.net/get-music-content/175191/fc037022.a.4719563-1/1000x1000",
        downloadURL: "https://music.yandex.ru/album/4719563/track/36210785",
      ));
    }
  }

  void _openBox() async {
    await Hive.openBox<Track>('trackBox');
    _trackBox = Hive.box<Track>('trackBox');
  }

  void addTrack(Track track) {
    tracks.add(track);
    notifyListeners();
  }

  void updateTrack(Track track, String oldName) {
    int index = tracks.indexWhere((item) => item.name == oldName);
    if (index != -1) {
      tracks.removeAt(index);
      tracks.insert(index, track);
      notifyListeners();
    }
  }

  void deleteTrack(Track track) {
    int index = tracks.indexWhere((item) => item.name == track.name);
    if (index != -1) {
      tracks.removeAt(index);
      notifyListeners();
    }
  }

  updateOrderList(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final track = tracks.removeAt(oldIndex);
    tracks.insert(newIndex, track);
    notifyListeners();
  }
}

class ThemeNotifier with ChangeNotifier {
  late ThemeData _themeData;
  late SharedPreferences _prefs;
  final String _key = 'theme_preference';
  ThemeData getTheme() => _themeData;

  ThemeNotifier(this._prefs) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    int isDark = _prefs.getInt(_key) ?? 0;
    _themeData = isDark == 1 ? ThemeData.dark() : ThemeData.light();
    notifyListeners();
  }

  void setTheme(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
    _prefs.setInt(_key, _themeData == ThemeData.dark() ? 1 : 0);
  }
}

class MyApp extends StatelessWidget{
  final SharedPreferences prefs;
  final bool firstStart;

  const MyApp({required this.prefs, required this.firstStart});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeNotifier>(context).getTheme(),
      onGenerateRoute: (settings) {
        if (settings.name == '/info_about_track') {
          final args = settings.arguments as Track;
          return MaterialPageRoute(
            builder: (context) => InfoAboutTrackScreen(track: args),
          );
        }
        if (settings.name == '/settings') {
          return MaterialPageRoute(
            builder: (context) => SettingsScreen(),
          );
        }
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) => PlayListScreen(),
          );
        }
        return null;
      },
      initialRoute: '/auth_code',
      routes: {
        '/auth_code': (context) => AuthCodeScreen(prefs: prefs, firstStart: firstStart),
      },
    );
  }
}

class PlayListScreen extends StatefulWidget {
  @override
  _PlayListScreenState createState() => _PlayListScreenState();
}

class _PlayListScreenState extends State<PlayListScreen> {
  late final TextEditingController _controllerName = TextEditingController();
  late final TextEditingController _controllerAuthor = TextEditingController();
  late final TextEditingController _controllerImageURL = TextEditingController();
  late final TextEditingController _controllerDownloadURL = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var trackList = Provider.of<TrackList>(context);

    void _showForm(BuildContext context, String action, [Track? trackItem]) {
      if(trackItem != null){
        _controllerName.text = trackItem.name;
        _controllerAuthor.text = trackItem.author;
        _controllerImageURL.text = trackItem.imageURL;
        _controllerDownloadURL.text = trackItem.downloadURL;
      }

      void fieldsClear() {
        _controllerName.clear();
        _controllerAuthor.clear();
        _controllerImageURL.clear();
        _controllerDownloadURL.clear();
      }

      String textButton = action=="add" ? "Добавить" : "Сохранить";
      if(action=="add") {
        fieldsClear();
        trackItem = null;
      }

      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: _controllerName,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                      ),
                    ),
                    TextFormField(
                      controller: _controllerAuthor,
                      decoration: const InputDecoration(
                        labelText: 'Автор',
                      ),
                    ),
                    TextFormField(
                      controller: _controllerImageURL,
                      decoration: const InputDecoration(
                        labelText: 'Ссылка на изображение',
                      ),
                    ),
                    TextFormField(
                      controller: _controllerDownloadURL,
                      decoration: const InputDecoration(
                        labelText: 'Ссылка на источник',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if(action == "add"){
                          trackList.addTrack(Track(
                            name: _controllerName.text,
                            author: _controllerAuthor.text,
                            imageURL: _controllerImageURL.text,
                            downloadURL: _controllerDownloadURL.text,
                          ));
                        }else if(trackItem != null){
                          trackList.updateTrack(Track(
                            name: _controllerName.text,
                            author: _controllerAuthor.text,
                            imageURL: _controllerImageURL.text,
                            downloadURL: _controllerDownloadURL.text,
                          ), trackItem.name.toString());
                        }
                        fieldsClear();
                        Navigator.pop(context);
                      },
                      child: Text(textButton),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Плейлист'),
        actions: [
          ElevatedButton(
              child: Icon(Icons.account_circle_rounded,),
              onPressed: (){Navigator.pushNamed(context, '/settings');},
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showForm(context, "add");
        },
        child: Text("+", style: TextStyle(fontSize: 20)),
      ),
      body: Center(
          child: ReorderableListView(
            children: [
              for (Track track in trackList.tracks)
                ListTile(
                  key: ValueKey(track),
                  title: Text(track.name),
                  subtitle: Text(track.author),
                  leading: Image.network(track.imageURL),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          _showForm(context, "update", track);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          trackList.deleteTrack(track);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/info_about_track',
                      arguments: track,
                    );
                  },
                ),
            ],
            onReorder: (oldIndex, newIndex) => trackList.updateOrderList(oldIndex, newIndex),
          )
      ),
    );
  }
}

class InfoAboutTrackScreen extends StatelessWidget {
  final Track track;
  InfoAboutTrackScreen({required this.track});

  void _launchURL({required String url}) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Информация о треке'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(track.imageURL),
            Text('${track.name}'),
            Text('${track.author}'),
            ElevatedButton(onPressed: (){_launchURL(url: '${track.downloadURL}');}, child: Text('ОТКРЫТЬ НА ЯНДЕКСЕ'))
          ],
        ),
      ),
    );
  }
}



class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool isDarkMode;
  late ThemeNotifier themeNotifier;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _locationController;
  String? _imagePath;
  late location_dart.LocationData _locationData;

  @override
  void initState() {
    super.initState();
    themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    isDarkMode = themeNotifier.getTheme() == ThemeData.dark();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _birthDateController = TextEditingController();
    _locationController = TextEditingController();
    _loadData();
  }

  void getLocationFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks.first;

      _locationController.text = place.locality.toString() + ", " +
          place.country.toString() + ", " +
          place.street.toString().toString() + ", " +
          place.postalCode.toString();

    } catch (e) {
      print("Ошибка получения информации о местоположении: $e");
    }
  }

  void _loadData() async {
    final userBox = Hive.box<User>('userBox');
    final userData = userBox.get(1);
    if (userData != null) {
      setState(() {
        _firstNameController.text = userData.firstName;
        _lastNameController.text = userData.lastName;
        _middleNameController.text = userData.middleName;
        _birthDateController.text = userData.birthDate;
        _imagePath = userData.imagePath;
        if (userData.locationLatitude != null && userData.locationLongitude != null) {
          getLocationFromCoordinates(userData.locationLatitude!, userData.locationLongitude!);
        }
      });
    }
  }

  void saveData() async {
    final userBox = Hive.box<User>('userBox');
    await userBox.put(
      1,
      User(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        middleName: _middleNameController.text,
        birthDate: _birthDateController.text,
        imagePath: _imagePath,
        locationLatitude: _locationData.latitude,
        locationLongitude: _locationData.longitude,
      ),
    );
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
      isDarkMode
          ? themeNotifier.setTheme(ThemeData.dark())
          : themeNotifier.setTheme(ThemeData.light());
    });
  }

  void updateImagePath(String? newPath) {
    setState(() {
      _imagePath = newPath;
    });
  }

  Future<void> _captureImageFromCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _locationData = await _getCurrentLocation();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakePictureScreen(
          camera: firstCamera,
          updateImagePath: updateImagePath,
        ),
      ),
    );
  }

  Future<void> _selectImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    _locationData = await _getCurrentLocation();

    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<location_dart.LocationData> _getCurrentLocation() async {
    final location = location_dart.Location();
    try {
      var serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return Future.error('Сервис местоположения отключен.');
        }
      }

      var permissionGranted = await location.hasPermission();
      if (permissionGranted == location_dart.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != location_dart.PermissionStatus.granted) {
          return Future.error('Нет разрешения на местоположение.');
        }
      }

      return await location.getLocation();
    } catch (e) {
      return Future.error('Ошибка получения местоположения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  children: <Widget>[
                    Center(
                      child: _imagePath != null
                          ? SizedBox(
                        width: 200,
                        height: 200,
                        child: ClipOval(
                          child: Image.file(File(_imagePath!)),
                        ),
                      )
                          : Text('Нет выбранного или сделанного фото'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _selectImageFromGallery();
                      },
                      child: Text('Выбрать из галереи'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _captureImageFromCamera();
                      },
                      child: Text('Сделать фото'),
                    ),

                    TextFormField(
                      enabled: false,
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Местоположение',
                      ),
                    ),

                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Фамилия',
                      ),
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Имя',
                      ),
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      controller: _middleNameController,
                      decoration: InputDecoration(
                        labelText: 'Отчество',
                      ),
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      controller: _birthDateController,
                      decoration: InputDecoration(
                        labelText: 'Дата рождения',
                      ),
                    ),
                    SizedBox(height: 20.0),
                    ElevatedButton(
                      onPressed: () {
                        saveData();
                      },
                      child: Text("Сохранить данные"),
                    ),
                    SizedBox(height: 20.0),
                    ElevatedButton(
                      onPressed: () {
                        toggleTheme();
                      },
                      child: Text("Смена темы"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(String?) updateImagePath;

  const TakePictureScreen({
    Key? key,
    required this.camera,
    required this.updateImagePath,
  }) : super(key: key);

  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Сделать фото')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();

            widget.updateImagePath(image.path);
            Navigator.pop(context, image.path);
          } catch (e) {
            print('Ошибка при захвате изображения: $e');
          }
        },
        child: Icon(Icons.camera),
      ),
    );
  }
}