# HoneyVPN — Контекст проекта для ИИ

## Что это
Windows VPN клиент **HoneyVPN** — форк FlClash (Flutter + Mihomo).  
Telegram бот **@honeyvpnru_bot** — продажа подписок в России.  
Telegram Mini App — личный кабинет с оплатой через YooKassa от 3₽.

---

## Серверная инфраструктура

| Роль | IP | Доступ |
|------|----|--------|
| Marzban panel | 213.108.21.58 | docker, admin/Admin2026xvtrv, https://xvtrv.ru:8443 |
| NL нода (боты+API) | 109.120.150.129 | root/291FYmxAB7cK |
| Germany нода | 77.221.157.169 | root/JOaB4fL5a2TV |
| France нода | 147.45.68.58 | root/1GKmLfy2vlOi |
| USA нода | 213.165.50.218 | root/sPcXh26xJso5 |
| Bridge 1 (Yandex LTE) | 81.26.178.109 | ubuntu/~/.ssh/yandex_cloud |
| Bridge 2 (Yandex LTE 2) | 158.160.159.239 | yc-user/~/.ssh/bridge2_new (только через France relay!) |
| Bridge 3 | 158.160.227.33 | yc-user/~/.ssh/yandex_cloud |

---

## Протокол подключения

**Только VLESS XHTTP REALITY на порту 443** (TCP полностью удалён).

Xray config (глобальный на всех нодах):
- XHTTP :443 VLESS REALITY: dest=www.microsoft.com:443, sni=yastatic.net, fp=chrome, path=/, mode=packet-up
- Private key: kDdPhtD4IdMidv4ZKuITNRf8qfyqOeKRHw2HJBpWADg
- Public key: qr9DbuDnRxLzgDBkhtTWX2OVi1u6PbM3a3DwUTaQHGc
- shortIds: fd9bc647, 023afa65

Marzban хосты (inbound тег VLESS TCP REALITY, реально xhttp):
- 🇷🇺→🇳🇱 LTE: 81.26.178.109:443 → Bridge 1 → NL 109.120.150.129:443
- 🇷🇺→🇫🇷 LTE: 158.160.159.239:443 → Bridge 2 (marzban-node) → France
- 🇳🇱 WiFi: 109.120.150.129:443 прямой
- 🇫🇷 WiFi: 147.45.68.58:443 прямой

Hysteria2 (отдельный протокол):
- Germany: hysteria2://1b839a5610546129e98d6f8b01e882a1@77.221.157.169:80?insecure=1&sni=bing.com
- USA: hysteria2://1b839a5610546129e98d6f8b01e882a1@213.165.50.218:443?insecure=1&sni=bing.com
- Bridge 2 → Germany UDP:80 (iptables DNAT)
- Bridge 3 → USA UDP:443 (iptables DNAT)

---

## Flutter приложение (эта папка)

**Репозиторий:** maksimmalygin0879-beep/vpn-app (private GitHub)  
**Исходники:** /opt/vpn-app-clean/ на сервере 109.120.150.129  
**CI/CD:** GitHub Actions build-windows.yaml (workflow_dispatch)  
**Установщик:** flutter_distributor → Inno Setup, только ru локаль

### Ключевые изменения от оригинального FlClash:

| Файл | Изменение |
|------|-----------|
| lib/common/path.dart | corePath = 'HoneyUtilityCore' |
| lib/common/constant.dart | helperService = 'HoneyUtilityHelperService' |
| windows/runner/Runner.rc | CompanyName/ProductName = HoneyVPN |
| lib/controller.dart | _handlerDisclaimer() = return; (нет попапа при старте) |
| lib/controller.dart | _initDefaultProfiles() label = '🍯 HoneyVPN' |
| lib/views/profiles/add.dart | принимает vless://, hy2://, base64, URL |
| lib/models/profile.dart | парсит proxy link/base64 (не только URL) |
| lib/common/proxy_link.dart | VLESS: flow=xtls-rprx-vision; xhttp: маппинг extra JSON |
| lib/state.dart | isPre = false |
| lib/views/dashboard/dashboard.dart | полностью переработан (PageView карусель) |
| assets/ | все иконки заменены на honey.png (медведь) |

### Dashboard (текущий дизайн):
- PageView карусель: одна подписка на страницу, последняя = Добавить подписку
- Статистика: NetworkSpeed + TrafficUsage вверху
- _PageDots анимированный индикатор
- Каждая страница: стрелки влево/вправо, имя профиля, кнопка пинг, список серверов
- Список серверов: tap = авто-подключение (DIRECT/REJECT/GLOBAL скрыты)
- Выбранный сервер: подсвечен primary color + галочка
- Задержка: зелёный <200ms, оранжевый <500ms, красный 500ms+

### package ID: com.follow/clash
Данные приложения: %APPDATA%\com.follow\clash
---

## Telegram боты (на 109.120.150.129)

### HoneyVPN бот (@honeyvpnru_bot)
- Код: /root/my_bot/main.py
- Сервис: honeyvpn-bot.service
- API: /root/my_bot/api.py → порт 8090 → nginx /honey/
- БД: PostgreSQL (PG_DSN в .env)

### AlphaVPN бот
- Код: /root/alphavpn/bot.py
- API: /root/alphavpn/api.py → порт 8088 → nginx /alpha/
- Сервис: alphavpn-bot.service

### Тариф HoneyVPN:
- 90₽ = 30 дней + 10 ГБ LTE трафика включено
- 3₽/день = 300 коп/день
- После расхода LTE: 4.5₽/ГБ (= 36 часов подписки), уведомление 1 раз при переходе
- Счётчик ГБ не сбрасывается, продолжает считать сверх лимита

---

## Telegram Mini App (Личный кабинет)

**URL:** https://xvtrv.ru:8443/honey/mini  
**HTML:** /root/my_bot/miniapp.html  
**Вебхук YooKassa:** https://xvtrv.ru:8443/honey/mini/webhook (подключён)

### YooKassa (прямой API, минималка 3₽):
- Shop ID: 1257051
- Secret key: в /root/my_bot/.env (YOOKASSA_SHOP_ID, YOOKASSA_SECRET_KEY)
- НЕ Telegram Payments — прямой REST API api.yookassa.ru/v3/payments

### Вкладки Mini App:
1. **Главная** — баланс (₽ + дней VPN), статус подписки, история пополнений
2. **Пополнить** — два режима:
   - Баланс: ввод суммы + пресеты 30/90/180/360₽
   - ГБ пакеты: 45₽=10ГБ, 180₽=50ГБ (LTE пакеты)
3. **Подключить** — ссылка подписки + кнопка HAPP (через xvtrv.ru:8443/honey/happ)
4. **Друзья** — реферальная ссылка + статистика

### API endpoints (/honey/mini/api/):
- POST /info → {active, days_left, expire_ts, balance_kop, sub_url, connect_url, referral, history}
- POST /create-payment → {payment_id, confirmation_url} (kind: topup_app | gb_package)
- GET /payment-status/{id} → {status}
- POST /mini/webhook → обработка YooKassa уведомлений

### Дизайн:
- Фон: #060504 (почти чёрный как лого)
- Акцент: #C49428 (матовое медовое золото)
- Логотип: https://honeyvpn.ru/bear.png (медведь без надписи)
- 4 вкладки внизу с SVG иконками

---

## Известные особенности / баги

1. **Bridge 2 SSH** — недоступен напрямую с VK Cloud, только через France как прокси
2. **Bridge 2 UFW** — Firewall reloaded говорит not enabled но правила работают; для UDP использовать  напрямую
3. **Marzban per-node config** — СЛИВАЕТСЯ с глобальным, не заменяет; не использовать для изменения портов
4. **Два xray процесса на Bridge 2** — standalone xray отключён (systemctl disable xray), работает только marzban-node
5. **INBOUNDS в docker-compose Bridge 2** = VLESS TCP REALITY (тег старый, реально xhttp)
6. **Трафик в Mini App** — пока 0/0, данные из Marzban не подключены к БД
7. **happ:// deeplink** — открывать через tg.openLink(https://xvtrv.ru:8443/honey/happ?t=TOKEN), не напрямую

---

## Файлы .env (109.120.150.129)

/root/my_bot/.env содержит:
- BOT_TOKEN, PG_DSN, PROVIDER_TOKEN (Telegram Payments — отдельно от YooKassa)
- YOOKASSA_SHOP_ID=1257051
- YOOKASSA_SECRET_KEY=live_...
- HAPP_IMPORT_PAGE, SUB_PATH, BOT_USERNAME

---

## Планы / TODO

- [ ] LTE биллинг: считать трафик на мостах, списывать 4.5₽/ГБ после 10ГБ лимита
- [ ] Уведомление при переходе на платный LTE (1 раз)
- [ ] Трафик в Mini App из Marzban API
- [ ] Народный ВПН → отдельный магазин YooKassa (старый webhook занят HoneyVPN)
