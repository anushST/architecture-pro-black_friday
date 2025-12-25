# Задание 7. Проектирование схем коллекций для шардирования данных

## 1. Коллекция orders
### Схема коллекции
```js
{
  _id: ObjectId,
  order_id: String,
  user_id: String,
  created_at: ISODate,
  items: [
    {
      product_id: String,
      name: String,
      price: Decimal128,
      quantity: Int32
    }
  ],
  status: String,
  total_amount: Decimal128,
  geo_zone: String
}
```
### Стратегия шардирования
**Шард-ключ**: { user_id: 1, created_at: 1 }

**Тип**: Compound ключ (хешированный user_id опционально)

Альтернатива: { user_id: "hashed" } если нужно более равномерное распределение.

### Обоснование
- user_id — основной параметр для поиска истории заказов конкретного пользователя. Все заказы одного пользователя окажутся на одном шарде, что ускорит выборку.
- created_at — позволяет эффективно работать с диапазонами дат и избегает роста данных только на одном шарде.
- Создание заказов распределится равномерно, так как пользователи разные.
- geo_zone не подходит — может быть перекос (Москва >> Калининград).

### Команда шардирования
```js
sh.shardCollection("mobile_world.orders", { user_id: 1, created_at: 1 })
```

## 2. Коллекция products
### Схема коллекции
```js
{
  _id: ObjectId,
  product_id: String,
  name: String,
  category: String,
  price: Decimal128,
  stock: [
    {
      geo_zone: String,
      quantity: Int32
    }
  ],
  attributes: {
    color: String,
    size: String
  }
}
```
### Стратегия шардирования
**Шард-ключ**: { product_id: "hashed" }

**Тип**: Hashed

### Обоснование
- product_id — уникальный идентификатор, по которому идет обращение при обновлении остатков и просмотре карточки товара.
- Hashed — равномерно распределяет товары по шардам, избегая hotspots при популярных товарах.
- category не подходит — будут горячие шарды на популярных категориях (электроника).
- Поиск по категориям станет broadcast-операцией, но это приемлемо для каталога. Можно добавить индекс по category.
- Обновления остатков будут попадать ровно на нужный шард.

### Команда шардирования
```js
sh.shardCollection("mobile_world.products", { product_id: "hashed" })
```

## 3. Коллекция carts
### Схема коллекции
```js
{
  _id: ObjectId,
  user_id: String,
  session_id: String,
  items: [
    {
      product_id: String,
      quantity: Int32
    }
  ],
  status: String,
  created_at: ISODate,
  updated_at: ISODate,
  expires_at: ISODate
}
```

### Стратегия шардирования
**Шард-ключ**: { user_id: 1, session_id: 1 }

**Тип**: Compound с поддержкой null

Альтернатива: { _id: "hashed" } если большинство корзин гостевые.

### Обоснование
- user_id — для авторизованных пользователей обеспечивает попадание на один шард при получении активной корзины.
- session_id — для гостей работает аналогично.
- Слияние корзин потребует обращения к двум шардам (гостевая + пользовательская), но это редкая операция.
- Корзины распределятся равномерно между пользователями и сессиями.
- status в ключ не включаем — он меняется, а шард-ключ иммутабелен.

### Команда шардирования
```js
sh.shardCollection("mobile_world.carts", { user_id: 1, session_id: 1 })
```