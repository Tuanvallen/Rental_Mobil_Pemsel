CREATE TABLE IF NOT EXISTS cars (
  id INT AUTO_INCREMENT PRIMARY KEY,
  plate VARCHAR(30) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  type VARCHAR(80) NOT NULL,
  year_model VARCHAR(10) NOT NULL,
  price_per_hour INT NOT NULL,
  available TINYINT(1) NOT NULL DEFAULT 1,
  image LONGTEXT NOT NULL,
  color VARCHAR(60) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS app_users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(80) NOT NULL UNIQUE,
  email VARCHAR(160) NOT NULL UNIQUE,
  password VARCHAR(160) NOT NULL,
  nik VARCHAR(40) NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS bookings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  car_id INT NOT NULL,
  user_id INT NULL,
  customer_name VARCHAR(200) NOT NULL,
  nik VARCHAR(40) NOT NULL,
  pickup DATETIME NOT NULL,
  dropoff DATETIME NOT NULL,
  hours DECIMAL(10,2) NOT NULL,
  total DECIMAL(14,2) NOT NULL,
  created_at DATETIME NOT NULL,
  CONSTRAINT fk_bookings_car
    FOREIGN KEY (car_id) REFERENCES cars(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_bookings_user
    FOREIGN KEY (user_id) REFERENCES app_users(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE cars MODIFY image LONGTEXT NOT NULL;

INSERT INTO cars
  (plate, name, type, year_model, price_per_hour, available, image, color)
VALUES
  ('AB 0851 BU', 'Daihatsu Ayla', 'Sedan', '2017', 20000, 0, 'assets/cars/pngwing.com_4.png', 'Kuning'),
  ('AB 1234 IH', 'Honda Corolla', 'Sedan', '2024', 100000, 0, 'assets/cars/pngegg_2.png', 'Putih'),
  ('AB 9877 CL', 'Honda Civic', 'Sport', '2077', 50000, 1, 'assets/cars/Civic.png', 'Putih'),
  ('AB A88B JO', 'Toyota Yaris', 'Sedan', '2018', 20000, 1, 'assets/cars/pngwing.com_3.png', 'Merah'),
  ('AD 1234 IH', 'Toyota Supri', 'Sport', '2077', 50000, 0, 'assets/cars/supra.png', 'Pink'),
  ('AU 4456 UI', 'Avanza', 'Sedan', '1945', 50000, 1, 'assets/cars/brio.png', 'Hitam'),
  ('B 9874 XYZ', 'Hiace', 'Minivan', '2018', 120000, 1, 'assets/cars/pngegg_1.png', 'Putih')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  type = VALUES(type),
  year_model = VALUES(year_model),
  price_per_hour = VALUES(price_per_hour),
  available = VALUES(available),
  image = VALUES(image),
  color = VALUES(color);

INSERT INTO app_users
  (username, email, password, nik, first_name, last_name)
VALUES
  ('banu', 'banu@gmail.com', '1234', '123123', 'Banu', 'Jogja'),
  ('budi123', 'budi@gmail.com', '123', '789789789', 'Budi', 'Waluyo')
ON DUPLICATE KEY UPDATE
  email = VALUES(email),
  password = VALUES(password),
  nik = VALUES(nik),
  first_name = VALUES(first_name),
  last_name = VALUES(last_name);
