import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mysql_client/mysql_client.dart';

class OnlineDatabase {
  OnlineDatabase._();

  static final OnlineDatabase instance = OnlineDatabase._();

  final MySQLConnectionPool _pool = MySQLConnectionPool(
    host: 'suwtzd.h.filess.io',
    port: 3307,
    userName: 'Rental_Mobil_acceptgas',
    password: '91eda70195d307f556e0ba721d61f409e127d0d2',
    databaseName: 'Rental_Mobil_acceptgas',
    maxConnections: 4,
    secure: false,
  );

  Future<List<Car>> fetchCars() async {
    final result = await _pool.execute(
      'SELECT id, plate, name, type, year_model, price_per_hour, available, image, color '
      'FROM cars ORDER BY id',
    );
    return result.rows.map((row) {
      final data = row.assoc();
      return Car(
        id: int.tryParse(data['id'] ?? ''),
        plate: data['plate'] ?? '',
        name: data['name'] ?? '',
        type: data['type'] ?? '',
        year: data['year_model'] ?? '',
        pricePerHour: int.tryParse(data['price_per_hour'] ?? '') ?? 0,
        available: (int.tryParse(data['available'] ?? '') ?? 0) == 1,
        image: data['image'] ?? '',
        color: data['color'] ?? '',
      );
    }).toList();
  }

  Future<List<AppUser>> fetchUsers() async {
    final result = await _pool.execute(
      'SELECT id, username, email, password, nik, first_name, last_name '
      'FROM app_users ORDER BY id',
    );
    return result.rows.map((row) {
      final data = row.assoc();
      return AppUser(
        id: int.tryParse(data['id'] ?? ''),
        username: data['username'] ?? '',
        email: data['email'] ?? '',
        password: data['password'] ?? '',
        nik: data['nik'] ?? '',
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
      );
    }).toList();
  }

  Future<List<Booking>> fetchBookings(List<Car> cars) async {
    final result = await _pool.execute(
      'SELECT b.id, b.car_id, b.customer_name, b.nik, b.pickup, b.dropoff, '
      'b.hours, b.total, b.created_at, c.plate, c.name, c.type, c.year_model, '
      'c.price_per_hour, c.available, c.image, c.color '
      'FROM bookings b '
      'JOIN cars c ON c.id = b.car_id '
      'ORDER BY b.created_at DESC, b.id DESC',
    );
    return result.rows.map((row) {
      final data = row.assoc();
      final carId = int.tryParse(data['car_id'] ?? '');
      final car = cars.where((item) => item.id == carId).firstOrNull ??
          Car(
            id: carId,
            plate: data['plate'] ?? '',
            name: data['name'] ?? '',
            type: data['type'] ?? '',
            year: data['year_model'] ?? '',
            pricePerHour: int.tryParse(data['price_per_hour'] ?? '') ?? 0,
            available: (int.tryParse(data['available'] ?? '') ?? 0) == 1,
            image: data['image'] ?? '',
            color: data['color'] ?? '',
          );
      return Booking(
        id: int.tryParse(data['id'] ?? ''),
        car: car,
        customerName: data['customer_name'] ?? '',
        nik: data['nik'] ?? '',
        pickup: _parseDatabaseDate(data['pickup']),
        dropoff: _parseDatabaseDate(data['dropoff']),
        hours: double.tryParse(data['hours'] ?? '') ?? 0,
        total: double.tryParse(data['total'] ?? '') ?? 0,
        createdAt: _parseDatabaseDate(data['created_at']),
      );
    }).toList();
  }

  Future<void> insertCar(Car car) async {
    await _pool.execute(
      'INSERT INTO cars (plate, name, type, year_model, price_per_hour, available, image, color) '
      'VALUES (:plate, :name, :type, :year_model, :price_per_hour, :available, :image, :color)',
      _carParams(car),
    );
  }

  Future<void> updateCar(Car car) async {
    await _pool.execute(
      'UPDATE cars SET plate = :plate, name = :name, type = :type, year_model = :year_model, '
      'price_per_hour = :price_per_hour, available = :available, image = :image, color = :color '
      'WHERE id = :id',
      {..._carParams(car), 'id': car.id},
    );
  }

  Future<void> deleteCar(Car car) async {
    if (car.id == null) return;
    await _pool.execute('DELETE FROM cars WHERE id = :id', {'id': car.id});
  }

  Future<void> insertUser(AppUser user) async {
    await _pool.execute(
      'INSERT INTO app_users (username, email, password, nik, first_name, last_name) '
      'VALUES (:username, :email, :password, :nik, :first_name, :last_name)',
      _userParams(user),
    );
  }

  Future<void> updateUser(AppUser user) async {
    await _pool.execute(
      'UPDATE app_users SET username = :username, email = :email, password = :password, '
      'nik = :nik, first_name = :first_name, last_name = :last_name WHERE id = :id',
      {..._userParams(user), 'id': user.id},
    );
  }

  Future<void> deleteUser(AppUser user) async {
    if (user.id == null) return;
    await _pool.execute('DELETE FROM app_users WHERE id = :id', {'id': user.id});
  }

  Future<void> insertBooking(Booking booking, AppUser user) async {
    await _pool.execute(
      'INSERT INTO bookings (car_id, user_id, customer_name, nik, pickup, dropoff, hours, total, created_at) '
      'VALUES (:car_id, :user_id, :customer_name, :nik, :pickup, :dropoff, :hours, :total, :created_at)',
      {
        'car_id': booking.car.id,
        'user_id': user.id,
        'customer_name': booking.customerName,
        'nik': booking.nik,
        'pickup': _formatDatabaseDate(booking.pickup),
        'dropoff': _formatDatabaseDate(booking.dropoff),
        'hours': booking.hours,
        'total': booking.total,
        'created_at': _formatDatabaseDate(booking.createdAt),
      },
    );
  }

  Future<void> deleteBooking(Booking booking) async {
    if (booking.id == null) return;
    await _pool.execute('DELETE FROM bookings WHERE id = :id', {'id': booking.id});
  }

  Map<String, dynamic> _carParams(Car car) {
    return {
      'plate': car.plate,
      'name': car.name,
      'type': car.type,
      'year_model': car.year,
      'price_per_hour': car.pricePerHour,
      'available': car.available ? 1 : 0,
      'image': car.image,
      'color': car.color,
    };
  }

  Map<String, dynamic> _userParams(AppUser user) {
    return {
      'username': user.username,
      'email': user.email,
      'password': user.password,
      'nik': user.nik,
      'first_name': user.firstName,
      'last_name': user.lastName,
    };
  }
}

DateTime _parseDatabaseDate(String? value) {
  if (value == null || value.isEmpty) return DateTime.now();
  return DateTime.tryParse(value.replaceFirst(' ', 'T')) ?? DateTime.now();
}

String _formatDatabaseDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

void main() {
  runApp(const RentalMobilApp());
}

class RentalMobilApp extends StatelessWidget {
  const RentalMobilApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6D4CFF);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Timbang Mlaku Transport',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF171326),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE7E5F4)),
          ),
        ),
      ),
      home: const RentalHome(),
    );
  }
}

class RentalHome extends StatefulWidget {
  const RentalHome({super.key});

  @override
  State<RentalHome> createState() => _RentalHomeState();
}

class _RentalHomeState extends State<RentalHome> {
  final OnlineDatabase _database = OnlineDatabase.instance;
  int _selectedIndex = 0;
  AppUser? _currentUser;
  int _adminTapCount = 0;
  bool _loadingDatabase = true;
  String? _databaseError;
  final List<Booking> _bookings = [];
  final List<AppUser> _users = [
    AppUser(
      username: 'banu',
      email: 'banu@gmail.com',
      password: '1234',
      nik: '123123',
      firstName: 'Banu',
      lastName: 'Jogja',
    ),
    AppUser(
      username: 'budi123',
      email: 'budi@gmail.com',
      password: '123',
      nik: '789789789',
      firstName: 'Budi',
      lastName: 'Waluyo',
    ),
  ];

  final List<Car> _cars = [
    Car(
      plate: 'AB 0851 BU',
      name: 'Daihatsu Ayla',
      type: 'Sedan',
      year: '2017',
      pricePerHour: 20000,
      available: false,
      image: 'assets/cars/pngwing.com_4.png',
      color: 'Kuning',
    ),
    Car(
      plate: 'AB 1234 IH',
      name: 'Honda Corolla',
      type: 'Sedan',
      year: '2024',
      pricePerHour: 100000,
      available: false,
      image: 'assets/cars/pngegg_2.png',
      color: 'Putih',
    ),
    Car(
      plate: 'AB 9877 CL',
      name: 'Honda Civic',
      type: 'Sport',
      year: '2077',
      pricePerHour: 50000,
      available: true,
      image: 'assets/cars/Civic.png',
      color: 'Putih',
    ),
    Car(
      plate: 'AB A88B JO',
      name: 'Toyota Yaris',
      type: 'Sedan',
      year: '2018',
      pricePerHour: 20000,
      available: true,
      image: 'assets/cars/pngwing.com_3.png',
      color: 'Merah',
    ),
    Car(
      plate: 'AD 1234 IH',
      name: 'Toyota Supri',
      type: 'Sport',
      year: '2077',
      pricePerHour: 50000,
      available: false,
      image: 'assets/cars/supra.png',
      color: 'Pink',
    ),
    Car(
      plate: 'AU 4456 UI',
      name: 'Avanza',
      type: 'Sedan',
      year: '1945',
      pricePerHour: 50000,
      available: true,
      image: 'assets/cars/brio.png',
      color: 'Hitam',
    ),
    Car(
      plate: 'B 9874 XYZ',
      name: 'Hiace',
      type: 'Minivan',
      year: '2018',
      pricePerHour: 120000,
      available: true,
      image: 'assets/cars/pngegg_1.png',
      color: 'Putih',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadOnlineData();
  }

  Future<void> _loadOnlineData() async {
    setState(() {
      _loadingDatabase = true;
      _databaseError = null;
    });
    try {
      final cars = await _database.fetchCars();
      final users = await _database.fetchUsers();
      final bookings = await _database.fetchBookings(cars);
      if (!mounted) return;
      setState(() {
        _cars
          ..clear()
          ..addAll(cars);
        _users
          ..clear()
          ..addAll(users);
        _bookings
          ..clear()
          ..addAll(bookings);
        _loadingDatabase = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _databaseError = error.toString();
        _loadingDatabase = false;
      });
    }
  }

  Future<void> _refreshOnlineData() async {
    try {
      final cars = await _database.fetchCars();
      final users = await _database.fetchUsers();
      final bookings = await _database.fetchBookings(cars);
      if (!mounted) return;
      setState(() {
        _cars
          ..clear()
          ..addAll(cars);
        _users
          ..clear()
          ..addAll(users);
        _bookings
          ..clear()
          ..addAll(bookings);
        if (_currentUser != null) {
          final previousUser = _currentUser!;
          _currentUser = _users
              .where(
                (user) =>
                    (previousUser.id != null && user.id == previousUser.id) ||
                    user.username == previousUser.username ||
                    user.nik == previousUser.nik,
              )
              .firstOrNull;
        }
      });
    } catch (error) {
      _showDatabaseMessage('Database error: $error');
    }
  }

  Future<void> _addCar(Car car) async {
    await _database.insertCar(car);
    await _refreshOnlineData();
  }

  Future<void> _updateCar(int index, Car car) async {
    await _database.updateCar(car);
    await _refreshOnlineData();
  }

  Future<void> _deleteCar(int index) async {
    await _database.deleteCar(_cars[index]);
    await _refreshOnlineData();
  }

  Future<void> _addUser(AppUser user) async {
    await _database.insertUser(user);
    await _refreshOnlineData();
  }

  Future<void> _updateUser(int index, AppUser user) async {
    await _database.updateUser(user);
    await _refreshOnlineData();
  }

  Future<void> _deleteUser(int index) async {
    await _database.deleteUser(_users[index]);
    await _refreshOnlineData();
  }

  Future<void> _addBooking(Booking booking) async {
    final user = _currentUser;
    if (user == null) return;
    await _database.insertBooking(booking, user);
    await _refreshOnlineData();
  }

  Future<void> _deleteBooking(int index) async {
    await _database.deleteBooking(_bookings[index]);
    await _refreshOnlineData();
  }

  void _showDatabaseMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openBooking([Car? car]) {
    if (_currentUser == null) {
      setState(() => _selectedIndex = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan register atau login akun dulu sebelum booking',
          ),
        ),
      );
      return;
    }
    setState(() => _selectedIndex = 2);
    _bookingKey.currentState?.selectCar(car);
  }

  void _openAdminGate() {
    _adminTapCount++;
    if (_adminTapCount < 5) return;
    _adminTapCount = 0;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminPage(
          cars: _cars,
          users: _users,
          bookings: _bookings,
          onAddCar: _addCar,
          onUpdateCar: _updateCar,
          onDeleteCar: _deleteCar,
          onAddUser: _addUser,
          onUpdateUser: _updateUser,
          onDeleteUser: _deleteUser,
          onDeleteBooking: _deleteBooking,
        ),
      ),
    );
  }

  final GlobalKey<BookingPageState> _bookingKey = GlobalKey<BookingPageState>();

  @override
  Widget build(BuildContext context) {
    if (_loadingDatabase) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_databaseError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Color(0xFF5F31DF)),
                const SizedBox(height: 12),
                const Text(
                  'Database online belum bisa terhubung',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _databaseError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadOnlineData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      HomePage(
        cars: _cars,
        onBookingTap: () => _openBooking(),
        onAdminAccess: _openAdminGate,
      ),
      CatalogPage(cars: _cars, onBookingTap: _openBooking),
      BookingPage(
        key: _bookingKey,
        cars: _cars.where((car) => car.available).toList(),
        currentUser: _currentUser,
        onBooked: (booking) {
          _addBooking(booking);
          setState(() => _selectedIndex = 3);
        },
      ),
      HistoryPage(bookings: _bookings),
      AccountPage(
        users: _users,
        currentUser: _currentUser,
        onUserLoggedIn: (user) => setState(() => _currentUser = user),
        onLogout: () => setState(() => _currentUser = null),
        onUserCreated: (user) {
          _addUser(user);
          setState(() => _currentUser = user);
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_filled_outlined),
            selectedIcon: Icon(Icons.directions_car_filled),
            label: 'Mobil',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Booking',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.cars,
    required this.onBookingTap,
    required this.onAdminAccess,
  });

  final List<Car> cars;
  final VoidCallback onBookingTap;
  final VoidCallback onAdminAccess;

  @override
  Widget build(BuildContext context) {
    final available = cars.where((car) => car.available).length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Container(
                height: 430,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                height: 430,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xE96B4DFF), Color(0xD8201544)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandHeader(light: true, onTap: onAdminAccess),
                    const SizedBox(height: 58),
                    const Text(
                      'Timbang Mlaku Transportation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Solusi urusan transportasi Jogja untuk liburan, bisnis, dan acara keluarga.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onBookingTap,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Booking Mobil Sekarang'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF5F31DF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        StatPill(value: '${cars.length}', label: 'Armada'),
                        const SizedBox(width: 12),
                        StatPill(value: '$available', label: 'Tersedia'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 6),
          sliver: SliverList.list(
            children: [
              const SectionTitle(
                title: 'Kenapa pilih kami',
                subtitle:
                    'Layanan yang sama seperti website, dibuat native untuk app.',
              ),
              const SizedBox(height: 14),
              const FeatureGrid(),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Cara pemesanan',
                subtitle:
                    'Isi data, pilih mobil, tentukan waktu, lalu konfirmasi invoice.',
              ),
              const SizedBox(height: 14),
              const OrderSteps(),
              const SizedBox(height: 24),
              const SectionTitle(
                title: 'Mobil populer',
                subtitle: 'Armada tersedia yang siap dibooking.',
              ),
              const SizedBox(height: 14),
              ...cars
                  .where((car) => car.available)
                  .take(3)
                  .map(
                    (car) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CompactCarTile(
                        car: car,
                        onTap: () => onBookingTap(),
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.cars,
    required this.onBookingTap,
  });

  final List<Car> cars;
  final ValueChanged<Car> onBookingTap;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String _type = 'Semua';
  String _sort = 'Tidak urut';

  @override
  Widget build(BuildContext context) {
    final types = ['Semua', ...widget.cars.map((car) => car.type).toSet()];
    var filtered = widget.cars
        .where((car) => _type == 'Semua' || car.type == _type)
        .toList();
    if (_sort == 'Termurah') {
      filtered.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
    } else if (_sort == 'Termahal') {
      filtered.sort((a, b) => b.pricePerHour.compareTo(a.pricePerHour));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Mobil')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DropdownButtonHideUnderline(
                child: FilterChipDropdown(
                  icon: Icons.filter_alt,
                  value: _type,
                  values: types,
                  onChanged: (value) => setState(() => _type = value),
                ),
              ),
              FilterChipDropdown(
                icon: Icons.sort,
                value: _sort,
                values: const ['Tidak urut', 'Termurah', 'Termahal'],
                onChanged: (value) => setState(() => _sort = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...filtered.map(
            (car) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: CarCard(
                car: car,
                onBookingTap: () => widget.onBookingTap(car),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.cars,
    required this.currentUser,
    required this.onBooked,
  });

  final List<Car> cars;
  final AppUser? currentUser;
  final ValueChanged<Booking> onBooked;

  @override
  State<BookingPage> createState() => BookingPageState();
}

class BookingPageState extends State<BookingPage> {
  Car? _selectedCar;
  DateTime _pickup = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _pickupTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _dropoff = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _dropoffTime = const TimeOfDay(hour: 9, minute: 0);

  void selectCar(Car? car) {
    if (!mounted) return;
    setState(() {
      _selectedCar = car ?? _selectedCar ?? widget.cars.firstOrNull;
    });
  }

  @override
  void didUpdateWidget(covariant BookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedCar ??= widget.cars.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock,
          title: 'Akun diperlukan',
          subtitle: 'Register atau login dulu untuk membuat booking mobil.',
        ),
      );
    }

    _selectedCar ??= widget.cars.firstOrNull;
    final car = _selectedCar;
    final start = _combine(_pickup, _pickupTime);
    final end = _combine(_dropoff, _dropoffTime);
    final hours = end.difference(start).inMinutes / 60;
    final total = car == null || hours <= 0
        ? 0.0
        : _calculateTotal(car.pricePerHour, hours);

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Mobil')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(
                    title: 'Form Booking',
                    subtitle: 'Pilih mobil dan jadwal sewa.',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<Car>(
                    initialValue: car,
                    items: widget.cars
                        .map(
                          (car) => DropdownMenuItem(
                            value: car,
                            child: Text(
                              '${car.name} - ${formatRupiah(car.pricePerHour)}/jam',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCar = value),
                    decoration: const InputDecoration(
                      labelText: 'Jenis Mobil',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DateTimePickerTile(
                    label: 'Tanggal Pickup',
                    value: formatDate(_pickup),
                    icon: Icons.calendar_today,
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _pickup,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (value != null) setState(() => _pickup = value);
                    },
                  ),
                  DateTimePickerTile(
                    label: 'Jam Pickup',
                    value: _pickupTime.format(context),
                    icon: Icons.schedule,
                    onTap: () async {
                      final value = await showTimePicker(
                        context: context,
                        initialTime: _pickupTime,
                      );
                      if (value != null) setState(() => _pickupTime = value);
                    },
                  ),
                  DateTimePickerTile(
                    label: 'Tanggal Dropoff',
                    value: formatDate(_dropoff),
                    icon: Icons.event_available,
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _dropoff,
                        firstDate: _pickup,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (value != null) setState(() => _dropoff = value);
                    },
                  ),
                  DateTimePickerTile(
                    label: 'Jam Dropoff',
                    value: _dropoffTime.format(context),
                    icon: Icons.timer_outlined,
                    onTap: () async {
                      final value = await showTimePicker(
                        context: context,
                        initialTime: _dropoffTime,
                      );
                      if (value != null) setState(() => _dropoffTime = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (car != null)
            InvoicePreview(
              car: car,
              hours: hours,
              total: total,
              pickup: start,
              dropoff: end,
              onConfirm: hours <= 0
                  ? null
                  : () {
                      final booking = Booking(
                        car: car,
                        customerName: user.fullName,
                        nik: user.nik,
                        pickup: start,
                        dropoff: end,
                        hours: hours,
                        total: total,
                        createdAt: DateTime.now(),
                      );
                      widget.onBooked(booking);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Booking berhasil dibuat'),
                        ),
                      );
                    },
            ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Booking')),
      body: bookings.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long,
              title: 'Belum ada booking',
              subtitle: 'Invoice yang Anda buat akan tampil di sini.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: bookings.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: BookingCard(booking: bookings[index]),
              ),
            ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.users,
    required this.currentUser,
    required this.onUserLoggedIn,
    required this.onLogout,
    required this.onUserCreated,
  });

  final List<AppUser> users;
  final AppUser? currentUser;
  final ValueChanged<AppUser> onUserLoggedIn;
  final VoidCallback onLogout;
  final ValueChanged<AppUser> onUserCreated;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final TextEditingController _loginUsernameController;
  late final TextEditingController _loginPasswordController;
  late final TextEditingController _registerFirstNameController;
  late final TextEditingController _registerLastNameController;
  late final TextEditingController _registerNikController;
  late final TextEditingController _registerUsernameController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerPasswordController;

  @override
  void initState() {
    super.initState();
    _loginUsernameController = TextEditingController();
    _loginPasswordController = TextEditingController();
    _registerFirstNameController = TextEditingController();
    _registerLastNameController = TextEditingController();
    _registerNikController = TextEditingController();
    _registerUsernameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    _registerNikController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (widget.currentUser != null) ...[
            _buildProfileCard(widget.currentUser!),
          ] else ...[
            const SectionTitle(
              title: 'Masuk Akun',
              subtitle: 'Register atau login dulu sebelum booking mobil.',
            ),
            const SizedBox(height: 14),
            _buildUserLoginCard(),
            const SizedBox(height: 14),
            _buildCreateUserCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(AppUser user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Profil Penyewa',
              subtitle: 'Akun ini aktif dan bisa dipakai untuk booking.',
            ),
            const SizedBox(height: 14),
            UserTile(user: user),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserLoginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Login User',
              subtitle: 'Masuk sebagai penyewa untuk memakai data akun.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _loginUsernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.account_circle),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _loginPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loginUser,
              icon: const Icon(Icons.login),
              label: const Text('Login User'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateUserCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Create User Baru',
              subtitle:
                  'Membuat akun penyewa lokal seperti halaman daftar web.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 560;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerFirstNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Awal',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerLastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Akhir',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerNikController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'NIK',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 12) / 2
                          : double.infinity,
                      child: TextField(
                        controller: _registerPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _createUser,
              icon: const Icon(Icons.person_add),
              label: const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }

  void _loginUser() {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;
    final matches = widget.users.where(
      (user) => user.username == username && user.password == password,
    );
    if (matches.isEmpty) {
      _showMessage('Username atau password user salah');
      return;
    }

    final user = matches.first;
    widget.onUserLoggedIn(user);
    _loginUsernameController.clear();
    _loginPasswordController.clear();
    _showMessage('Login user berhasil');
  }

  void _createUser() {
    final firstName = _registerFirstNameController.text.trim();
    final lastName = _registerLastNameController.text.trim();
    final nik = _registerNikController.text.trim();
    final username = _registerUsernameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    if ([
      firstName,
      nik,
      username,
      email,
      password,
    ].any((value) => value.isEmpty)) {
      _showMessage('Nama awal, NIK, username, email, dan password wajib diisi');
      return;
    }
    final duplicate = widget.users.any(
      (user) =>
          user.username == username || user.email == email || user.nik == nik,
    );
    if (duplicate) {
      _showMessage('Username, email, atau NIK sudah digunakan');
      return;
    }

    final user = AppUser(
      username: username,
      email: email,
      password: password,
      nik: nik,
      firstName: firstName,
      lastName: lastName,
    );
    widget.onUserCreated(user);
    _registerFirstNameController.clear();
    _registerLastNameController.clear();
    _registerNikController.clear();
    _registerUsernameController.clear();
    _registerEmailController.clear();
    _registerPasswordController.clear();
    _showMessage('User baru berhasil dibuat dan langsung aktif');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.cars,
    required this.users,
    required this.bookings,
    required this.onAddCar,
    required this.onUpdateCar,
    required this.onDeleteCar,
    required this.onAddUser,
    required this.onUpdateUser,
    required this.onDeleteUser,
    required this.onDeleteBooking,
  });

  final List<Car> cars;
  final List<AppUser> users;
  final List<Booking> bookings;
  final Future<void> Function(Car car) onAddCar;
  final Future<void> Function(int index, Car car) onUpdateCar;
  final Future<void> Function(int index) onDeleteCar;
  final Future<void> Function(AppUser user) onAddUser;
  final Future<void> Function(int index, AppUser user) onUpdateUser;
  final Future<void> Function(int index) onDeleteUser;
  final Future<void> Function(int index) onDeleteBooking;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _adminUsernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _adminPasswordController =
      TextEditingController();
  bool _loggedIn = false;

  static const List<String> _carImages = [
    'assets/cars/pngwing.com_4.png',
    'assets/cars/pngegg_2.png',
    'assets/cars/Civic.png',
    'assets/cars/pngwing.com_3.png',
    'assets/cars/supra.png',
    'assets/cars/brio.png',
    'assets/cars/pngegg_1.png',
  ];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return _buildLogin();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          actions: [
            IconButton(
              onPressed: () => setState(() => _loggedIn = false),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.directions_car), text: 'Mobil'),
              Tab(icon: Icon(Icons.people), text: 'User'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Pesanan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboard(),
            _buildCarsCrud(),
            _buildUsersCrud(),
            _buildBookingsCrud(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Login Admin',
                        subtitle: 'Masuk untuk mengelola data aplikasi.',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _adminUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.admin_panel_settings),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _adminPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loginAdmin,
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final available = widget.cars.where((car) => car.available).length;
    final revenue = widget.bookings.fold<double>(
      0,
      (sum, booking) => sum + booking.total,
    );

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle(
          title: 'Ringkasan',
          subtitle: 'Data operasional rental mobil lokal.',
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            AdminMetric(
              title: 'Mobil',
              value: '${widget.cars.length}',
              icon: Icons.directions_car,
            ),
            AdminMetric(
              title: 'Tersedia',
              value: '$available',
              icon: Icons.check_circle,
            ),
            AdminMetric(
              title: 'User',
              value: '${widget.users.length}',
              icon: Icons.people,
            ),
            AdminMetric(
              title: 'Pesanan',
              value: '${widget.bookings.length}',
              icon: Icons.receipt,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminMetric(
          title: 'Pendapatan',
          value: formatRupiah(revenue),
          icon: Icons.payments,
          wide: true,
        ),
      ],
    );
  }

  Widget _buildCarsCrud() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionTitle(
                title: 'CRUD Mobil',
                subtitle: 'Tambah, ubah, dan hapus data armada.',
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCarForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...widget.cars.asMap().entries.map((entry) {
          final index = entry.key;
          final car = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: SizedBox(
                  width: 76,
                  child: CarImage(path: car.image, fit: BoxFit.contain),
                ),
                title: Text(
                  car.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${car.plate} - ${car.type} - ${formatRupiah(car.pricePerHour)}/jam',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _showCarForm(index: index, car: car),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit mobil',
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _deleteCar(index),
                      icon: const Icon(Icons.delete),
                      tooltip: 'Hapus mobil',
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildUsersCrud() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionTitle(
                title: 'CRUD User',
                subtitle: 'Kelola akun penyewa lokal.',
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showUserForm(),
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...widget.users.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEEAFE),
                  foregroundColor: Color(0xFF5F31DF),
                  child: Icon(Icons.person),
                ),
                title: Text(
                  user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${user.username} - ${user.email} - NIK ${user.nik}',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _showUserForm(index: index, user: user),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit user',
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _deleteUser(index),
                      icon: const Icon(Icons.delete),
                      tooltip: 'Hapus user',
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBookingsCrud() {
    if (widget.bookings.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long,
        title: 'Belum ada pesanan',
        subtitle: 'Pesanan user akan tampil di sini.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: widget.bookings.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            BookingCard(booking: widget.bookings[index]),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => _deleteBooking(index),
                icon: const Icon(Icons.delete),
                tooltip: 'Hapus pesanan',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCarForm({int? index, Car? car}) async {
    final plate = TextEditingController(text: car?.plate ?? '');
    final name = TextEditingController(text: car?.name ?? '');
    final type = TextEditingController(text: car?.type ?? '');
    final year = TextEditingController(text: car?.year ?? '');
    final price = TextEditingController(
      text: car?.pricePerHour.toString() ?? '',
    );
    final color = TextEditingController(text: car?.color ?? '');
    var available = car?.available ?? true;
    var image = car?.image ?? _carImages.first;
    final selectedAssetImage = _carImages.contains(image) ? image : null;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Tambah Mobil' : 'Edit Mobil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: plate,
                  decoration: const InputDecoration(labelText: 'Plat Mobil'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama Mobil'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: type,
                  decoration: const InputDecoration(labelText: 'Tipe Mobil'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: year,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tahun'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga per Jam'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: color,
                  decoration: const InputDecoration(labelText: 'Warna'),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F2FE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE7E5F4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CarImage(path: image, fit: BoxFit.contain),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedAssetImage,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Gambar Asset',
                    prefixIcon: Icon(Icons.image),
                  ),
                  items: _carImages
                      .map(
                        (asset) => DropdownMenuItem(
                          value: asset,
                          child: Text(asset.split('/').last),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => image = value);
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 82,
                        maxWidth: 1200,
                      );
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      final extension = picked.name.split('.').last.toLowerCase();
                      final mimeType = extension == 'png'
                          ? 'image/png'
                          : extension == 'webp'
                              ? 'image/webp'
                              : 'image/jpeg';
                      setDialogState(
                        () => image = 'data:$mimeType;base64,${base64Encode(bytes)}',
                      );
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Gambar dari Galeri'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tersedia'),
                  value: available,
                  onChanged: (value) => setDialogState(() => available = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final parsedPrice = int.tryParse(price.text.trim());
                if ([
                      plate.text,
                      name.text,
                      type.text,
                      year.text,
                      color.text,
                    ].any((value) => value.trim().isEmpty) ||
                    parsedPrice == null) {
                  _showMessage('Lengkapi data mobil dengan benar');
                  return;
                }
                final newCar = Car(
                  id: car?.id,
                  plate: plate.text.trim(),
                  name: name.text.trim(),
                  type: type.text.trim(),
                  year: year.text.trim(),
                  pricePerHour: parsedPrice,
                  available: available,
                  image: image,
                  color: color.text.trim(),
                );
                if (index == null) {
                  await widget.onAddCar(newCar);
                } else {
                  await widget.onUpdateCar(index, newCar);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                _showMessage(
                  index == null ? 'Mobil ditambahkan' : 'Mobil diperbarui',
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserForm({int? index, AppUser? user}) async {
    final firstName = TextEditingController(text: user?.firstName ?? '');
    final lastName = TextEditingController(text: user?.lastName ?? '');
    final nik = TextEditingController(text: user?.nik ?? '');
    final username = TextEditingController(text: user?.username ?? '');
    final email = TextEditingController(text: user?.email ?? '');
    final password = TextEditingController(text: user?.password ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Tambah User' : 'Edit User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Nama Awal'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Nama Akhir'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nik,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'NIK'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if ([
                firstName.text,
                nik.text,
                username.text,
                email.text,
                password.text,
              ].any((value) => value.trim().isEmpty)) {
                _showMessage(
                  'Nama awal, NIK, username, email, dan password wajib diisi',
                );
                return;
              }
              final duplicate = widget.users.asMap().entries.any((entry) {
                if (entry.key == index) return false;
                final existing = entry.value;
                return existing.username == username.text.trim() ||
                    existing.email == email.text.trim() ||
                    existing.nik == nik.text.trim();
              });
              if (duplicate) {
                _showMessage('Username, email, atau NIK sudah digunakan');
                return;
              }
              final newUser = AppUser(
                id: user?.id,
                username: username.text.trim(),
                email: email.text.trim(),
                password: password.text,
                nik: nik.text.trim(),
                firstName: firstName.text.trim(),
                lastName: lastName.text.trim(),
              );
              if (index == null) {
                await widget.onAddUser(newUser);
              } else {
                await widget.onUpdateUser(index, newUser);
              }
              if (!context.mounted) return;
              Navigator.pop(context);
              _showMessage(
                index == null ? 'User ditambahkan' : 'User diperbarui',
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCar(int index) async {
    await widget.onDeleteCar(index);
    _showMessage('Mobil dihapus');
  }

  Future<void> _deleteUser(int index) async {
    await widget.onDeleteUser(index);
    _showMessage('User dihapus');
  }

  Future<void> _deleteBooking(int index) async {
    await widget.onDeleteBooking(index);
    _showMessage('Pesanan dihapus');
  }

  void _loginAdmin() {
    final username = _adminUsernameController.text.trim();
    final password = _adminPasswordController.text;
    if (username == 'admin' && password == 'admin') {
      setState(() => _loggedIn = true);
      _showMessage('Login admin berhasil');
      return;
    }
    _showMessage('Username atau password admin salah');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class Car {
  const Car({
    this.id,
    required this.plate,
    required this.name,
    required this.type,
    required this.year,
    required this.pricePerHour,
    required this.available,
    required this.image,
    required this.color,
  });

  final int? id;
  final String plate;
  final String name;
  final String type;
  final String year;
  final int pricePerHour;
  final bool available;
  final String image;
  final String color;
}

class AppUser {
  const AppUser({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    required this.nik,
    required this.firstName,
    required this.lastName,
  });

  final int? id;
  final String username;
  final String email;
  final String password;
  final String nik;
  final String firstName;
  final String lastName;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }
}

class Booking {
  const Booking({
    this.id,
    required this.car,
    required this.customerName,
    required this.nik,
    required this.pickup,
    required this.dropoff,
    required this.hours,
    required this.total,
    required this.createdAt,
  });

  final int? id;
  final Car car;
  final String customerName;
  final String nik;
  final DateTime pickup;
  final DateTime dropoff;
  final double hours;
  final double total;
  final DateTime createdAt;
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.light = false, this.onTap});

  final bool light;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : const Color(0xFF171326);
    final content = Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (light)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Text(
          'Timbang Mlaku\nTransport',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF171326),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700, height: 1.35),
        ),
      ],
    );
  }
}

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      Feature(
        'Armada Banyak',
        'Unit rutin ditambah untuk berbagai kebutuhan.',
        Icons.car_rental,
      ),
      Feature(
        'Driver Ramah',
        'Driver berpengalaman dan nyaman diajak perjalanan.',
        Icons.support_agent,
      ),
      Feature(
        'Harga Murah',
        'Tarif kompetitif untuk liburan dan bisnis.',
        Icons.sell,
      ),
      Feature(
        'Antar Jemput',
        'Kemudahan pickup dari beberapa titik di Jogja.',
        Icons.location_on,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 680 ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: const Color(0xFF5F31DF), size: 30),
                const Spacer(),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Feature {
  const Feature(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}

class OrderSteps extends StatelessWidget {
  const OrderSteps({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Lengkapi profil penyewa dan NIK.',
      'Pilih mobil sesuai kebutuhan perjalanan.',
      'Tentukan tanggal serta jam pickup dan dropoff.',
      'Konfirmasi invoice lalu hubungi admin untuk pembayaran.',
      'Mobil siap dipakai.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEEEAFE),
                  foregroundColor: const Color(0xFF5F31DF),
                  child: Text('${i + 1}'),
                ),
                title: Text(steps[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class CarImage extends StatelessWidget {
  const CarImage({super.key, required this.path, this.fit = BoxFit.contain});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit);
    }

    if (path.startsWith('data:image')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex != -1) {
        return Image.memory(
          base64Decode(path.substring(commaIndex + 1)),
          fit: fit,
        );
      }
    }

    return Image.file(File(path), fit: fit);
  }
}

class CompactCarTile extends StatelessWidget {
  const CompactCarTile({super.key, required this.car, required this.onTap});

  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: SizedBox(
          width: 72,
          child: CarImage(path: car.image, fit: BoxFit.contain),
        ),
        title: Text(
          car.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${car.type} - ${formatRupiah(car.pricePerHour)}/jam'),
        trailing: IconButton.filledTonal(
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Booking',
        ),
      ),
    );
  }
}

class FilterChipDropdown extends StatelessWidget {
  const FilterChipDropdown({
    super.key,
    required this.icon,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final IconData icon;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E5F4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: values
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          selectedItemBuilder: (context) => values
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: const Color(0xFF5F31DF)),
                    const SizedBox(width: 8),
                    Text(item),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car, required this.onBookingTap});

  final Car car;
  final VoidCallback onBookingTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: car.available ? Colors.white : const Color(0xFF2D2A37),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    car.name,
                    style: TextStyle(
                      color: car.available
                          ? const Color(0xFF171326)
                          : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusBadge(available: car.available),
              ],
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 2.3,
              child: CarImage(path: car.image, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoChip(
                  icon: Icons.badge,
                  label: car.plate,
                  dark: !car.available,
                ),
                InfoChip(
                  icon: Icons.category,
                  label: car.type,
                  dark: !car.available,
                ),
                InfoChip(
                  icon: Icons.calendar_month,
                  label: car.year,
                  dark: !car.available,
                ),
                InfoChip(
                  icon: Icons.palette,
                  label: car.color,
                  dark: !car.available,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: car.available
                    ? const Color(0xFFF3F0FF)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: Color(0xFF5F31DF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${formatRupiah(car.pricePerHour)} / jam',
                      style: TextStyle(
                        color: car.available
                            ? const Color(0xFF171326)
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: car.available ? onBookingTap : null,
                    child: Text(car.available ? 'Booking' : 'Habis'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: available ? const Color(0xFFE6F7EE) : const Color(0xFFFFE6E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        available ? 'Tersedia' : 'Habis',
        style: TextStyle(
          color: available ? const Color(0xFF08753B) : const Color(0xFFB42318),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: dark ? Colors.white70 : const Color(0xFF5F31DF),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF171326),
            ),
          ),
        ],
      ),
    );
  }
}

class DateTimePickerTile extends StatelessWidget {
  const DateTimePickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class InvoicePreview extends StatelessWidget {
  const InvoicePreview({
    super.key,
    required this.car,
    required this.hours,
    required this.total,
    required this.pickup,
    required this.dropoff,
    required this.onConfirm,
  });

  final Car car;
  final double hours;
  final double total;
  final DateTime pickup;
  final DateTime dropoff;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Invoice Sewa Mobil',
              subtitle: 'Ringkasan biaya akan dihitung otomatis.',
            ),
            const SizedBox(height: 14),
            InvoiceRow(label: 'Jenis Mobil', value: car.name),
            InvoiceRow(
              label: 'Pickup',
              value: '${formatDate(pickup)} ${formatTime(pickup)}',
            ),
            InvoiceRow(
              label: 'Dropoff',
              value: '${formatDate(dropoff)} ${formatTime(dropoff)}',
            ),
            InvoiceRow(
              label: 'Durasi',
              value: hours <= 0
                  ? 'Tanggal belum valid'
                  : '${hours.toStringAsFixed(1)} jam',
            ),
            InvoiceRow(
              label: 'Biaya / jam',
              value: formatRupiah(car.pricePerHour),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Biaya',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(
                    color: Color(0xFF5F31DF),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle),
                label: const Text('Konfirmasi Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceRow extends StatelessWidget {
  const InvoiceRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.car.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  formatRupiah(booking.total),
                  style: const TextStyle(
                    color: Color(0xFF5F31DF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Penyewa: ${booking.customerName} - NIK ${booking.nik}'),
            const SizedBox(height: 6),
            Text(
              'Pickup: ${formatDate(booking.pickup)} ${formatTime(booking.pickup)}',
            ),
            Text(
              'Dropoff: ${formatDate(booking.dropoff)} ${formatTime(booking.dropoff)}',
            ),
            Text('Durasi: ${booking.hours.toStringAsFixed(1)} jam'),
          ],
        ),
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEEAFE),
          foregroundColor: Color(0xFF5F31DF),
          child: Icon(Icons.person),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${user.username} - ${user.email}\nNIK ${user.nik}'),
        isThreeLine: true,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF5F31DF)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminMetric extends StatelessWidget {
  const AdminMetric({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.wide = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEAFE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF5F31DF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: wide ? 24 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _combine(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

double _calculateTotal(int pricePerHour, double hours) {
  if (hours <= 24) return pricePerHour * hours;
  final fullDays = hours ~/ 24;
  final remainingHours = hours % 24;
  return (fullDays * 24 * pricePerHour) + (remainingHours * pricePerHour);
}

String formatRupiah(num value) {
  final number = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < number.length; i++) {
    final reverseIndex = number.length - i;
    buffer.write(number[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write('.');
  }
  return 'Rp ${buffer.toString()}';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
