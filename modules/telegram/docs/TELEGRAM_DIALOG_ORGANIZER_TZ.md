# Техническое задание: Telegram Dialog Organizer — модуль Ayaya

Версия: 1.1
Дата: 2026-08-19
Статус: проектное ТЗ, без реализации

## 1. Назначение

Создать модуль `telegram` для локальной организации диалогов Telegram по папкам. Модуль работает внутри Ayaya за маршрутом `/m/telegram`, не требует Telegram Premium и применяет изменения только после явного подтверждения пользователя.

Модуль является самостоятельным Ayaya-модулем. Core предоставляет идентичность пользователя, доступ и маршрутизацию, но не содержит Telegram-бизнес-логику, не хранит Telegram-сессии и не вызывает Telegram API.

Главные принципы:

- анализ и хранение данных выполняются локально;
- до подтверждения запрещены mutating-вызовы Telegram API;
- чужие папки и ручные изменения пользователя не перезаписываются автоматически;
- лимиты Telegram получаются динамически и не зашиваются в код;
- session-файлы, API hash, коды входа и содержимое сообщений не передаются в Core или внешние сервисы.

## 2. Граница модуля в Ayaya

```text
Browser
  -> NGINX /m/telegram
  -> Core auth_request
  -> telegram_app
  -> Telegram API

Core
  -> telegram_adapter (/ayaya/manifest, /ayaya/health/*, /ayaya/status)
  -> telegram_adapter -> telegram_app /internal/ayaya/status
```

### 2.1. `telegram_app`

Владеет:

- UI модуля под `/m/telegram`;
- локальными пользователями, связанными с Core user ID;
- авторизацией Telegram;
- зашифрованными Telegram-сессиями и интеграционными секретами;
- чтением диалогов и текущих папок;
- правилами, классификацией, dry-run, diff и синхронизацией;
- базой данных и миграциями;
- внутренним endpoint статуса для Adapter.

### 2.2. `telegram_adapter`

Владеет только Adapter Protocol v1:

- чтением `module.yml`;
- проверкой adapter secret;
- manifest, live, ready и status endpoints;
- запросом внутреннего статуса `telegram_app`.

Adapter не принимает пользовательский трафик, не хранит Telegram-сессии и не проксирует Telegram API.

### 2.3. Core и NGINX

Core владеет регистрацией модуля, политикой доступа, глобальной аутентификацией, снимками manifest/status и навигацией. NGINX выполняет `auth_request`, удаляет входящие недоверенные `X-Ayaya-*` headers и добавляет доверенные headers при проксировании в `telegram_app`.

Core никогда не обращается к `telegram_app` напрямую. Core видит только Adapter. Внутренний status endpoint доступен только Adapter по приватной сети и отдельному секрету.

## 3. Module Contract

Структура bundle:

```text
modules/telegram/
  module.yml
  compose.yml
  app/
  adapter/
  docs/
    README.md
    CONTRACT.md
    TELEGRAM_DIALOG_ORGANIZER_TZ.md
```

`README.md` и `CONTRACT.md` обязательны для реализации модуля и должны описывать build/start, явные миграции, healthchecks, rollback, persistent storage, secrets, internal ports, сетевую топологию и точный NGINX route.

Минимальный `module.yml`:

```yaml
identity:
  module_key: telegram
  name: Telegram Dialog Organizer
  version: 0.1.0

protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1

presentation:
  description: Local Telegram dialog organization
  icon: messages-square
  category: productivity

routes:
  ui_base_path: /m/telegram
  api_base_path: /m/telegram/api

access:
  default_policy: authenticated
```

Adapter должен реализовать:

```text
GET /ayaya/manifest
GET /ayaya/health/live
GET /ayaya/health/ready
GET /ayaya/status
```

Каждый endpoint требует `Authorization: Bearer <TELEGRAM_ADAPTER_SECRET>`. Секрет не логируется. `ready` успешен только при валидном manifest и доступном внутреннем статусе приложения.

## 4. Пользователь и безопасность границы

`telegram_app` принимает только доверенные headers от NGINX:

- `X-Ayaya-User-Id` — обязательный стабильный идентификатор;
- `X-Ayaya-Module-Key` — обязан быть `telegram`;
- `X-Ayaya-User-Email`;
- `X-Ayaya-User-Display-Name`;
- `X-Ayaya-User-Role`;
- `X-Ayaya-Request-Id`.

При отсутствии user ID или несовпадении module key приложение возвращает `401`. Core admin не получает автоматический доступ к Telegram-данным другого пользователя.

Каждый Telegram account принадлежит локальному module user. В первой версии один пользователь Ayaya может подключить один Telegram account; поддержка нескольких аккаунтов откладывается.

NGINX обязан удалять все клиентские `X-Ayaya-*` headers до `auth_request`, не проксировать произвольные входящие заголовки и добавлять только значения, полученные от Core. Прямой доступ к `telegram_app` не допускается даже из host-сети.

Все browser-операции, меняющие состояние (`connect`, отправка кода, `apply`, `rollback`, изменение правил, остановка операции и disconnect), выполняются только через POST/PUT/PATCH/DELETE и защищаются synchronizer CSRF token. Дополнительно проверяются `Origin`/Fetch Metadata; CORS выключен по умолчанию.

## 5. Функциональный объём первой версии

Входит:

- вход в пользовательский Telegram account с 2FA;
- локальная авторизованная сессия;
- read-only импорт диалогов, текущих папок и динамических лимитов;
- классификация по метаданным и опциональному фрагменту последних сообщений;
- ручная корректировка предложений;
- правила, исключения и ручные назначения;
- dry-run и подробный diff;
- создание, обновление и удаление только управляемых приложением папок;
- повторная инкрементальная синхронизация;
- checkpoint, журнал операций и откат последней успешной операции;
- режим «только чтение»;
- русский и английский интерфейс.

Не входит:

- отправка сообщений;
- чтение полной истории сообщений;
- массовое переименование чатов;
- изменение архивирования, mute, pin и privacy settings;
- несколько Telegram-аккаунтов на одного пользователя;
- облачный backend или передача session-файла за пределы `telegram_app`;
- обход Premium-ограничений;
- автоматическая отправка приглашений;
- синхронизация папок между разными аккаунтами.

## 6. Пользовательский сценарий

1. Пользователь открывает `/m/telegram` через Ayaya.
2. Модуль показывает состояние подключения и предлагает авторизацию Telegram.
3. Пользователь вводит API ID, API hash, номер телефона или выбирает QR-вход, код и пароль 2FA.
4. Модуль сохраняет только зашифрованное состояние сессии и показывает имя аккаунта.
5. Пользователь запускает «Разобрать диалоги» в безопасном режиме — только названия, типы и другие метаданные.
6. Модуль формирует предложения и показывает уверенность, причины, неопределённые элементы и лимиты.
7. Пользователь редактирует предложения и открывает diff.
8. Только после подтверждения модуль выполняет план, сохраняет checkpoint и показывает результат каждой операции.
9. Повторный запуск обновляет только управляемые папки и отправляет новые диалоги в предложения.

## 7. UI

Главный экран показывает статус подключения, аккаунт, дату синхронизации, режим «Только анализ» или «Готово к применению», кнопку остановки и карточки папок с количеством чатов, лимитом и свободным местом.

Экран предложений поддерживает поиск, фильтры, массовые действия и колонки:

- чат, аватар, название и username;
- тип диалога;
- текущие папки;
- предлагаемая папка;
- уверенность;
- использованные признаки;
- принять, изменить, пропустить или заблокировать правило.

Команда «Почему?» показывает только фактически использованные признаки. Текст сообщений не показывается, если анализ сообщений отключён.

Экран diff обязан перечислять создаваемые, обновляемые и удаляемые управляемые папки, добавляемые и удаляемые чаты, изменения порядка и все конфликты. Кнопка подтверждения содержит число изменений.

Неопределённые и конфликтные диалоги не назначаются автоматически. Пользователь может назначить их вручную, оставить в «Прочее», исключить навсегда или создать правило.

## 8. Модель папок и лимиты

Базовые категории: Люди, Работа, Проекты, Семья, Группы, Каналы, Боты, Важное, Непрочит., Прочее. Шаблон всегда показывается до применения.

Название папки должно соответствовать актуальному ограничению Telegram по длине. Лимиты количества папок и чатов модуль получает из актуальной конфигурации Telegram при каждом запуске и перед применением через `help.getAppConfig`. Значения кэшируются вместе с hash конфигурации, но кэш не заменяет повторную проверку перед записью. Обрабатываются ключи `dialog_filters_limit_*`, `dialog_filters_chats_limit_*` и `dialogs_folder_pinned_limit_*`; при отсутствии ключа применяются документированные Telegram defaults. При неизвестном entitlement используется безопасный нижний предел и блокирующее предупреждение.

Ограничение длины названия папки также должно иметь источник и versioned fallback. Перед каждым write выполняется локальная валидация названия и лимитов.

При переполнении модуль:

- создаёт сегменты (`Каналы 1`, `Каналы 2`) только после подтверждения;
- либо предлагает исключить или перенести часть чатов;
- никогда не пытается превысить лимит.

Папки могут пересекаться. Режим «Витрины» включён по умолчанию; режим «Одна категория» запрещает пересечения только между пользовательскими категориями.

Папки, созданные вне модуля, имеют `managed_by_app = false` и не изменяются.

Управляемой считается только папка, созданная модулем и подтверждённая immutable ownership record с account ID, Telegram folder ID и fingerprint последнего применённого состояния. Неизвестные, shared/imported (`dialogFilterChatlist`) и изменённые извне папки считаются foreign и immutable. Удаление управляемой папки разрешено только при совпадении последнего applied fingerprint и отдельном подтверждении.

Telegram dialog filter обновляется целиком. Для каждого поля и порядка задаётся политика `preserve`, `conflict` или `overwrite after explicit confirmation`; модуль не моделирует изменение одного чата как независимый удалённый write.

## 9. Классификация и правила

Приоритет признаков:

1. постоянное исключение;
2. явное ручное назначение;
3. правило по chat ID;
4. правило по username;
5. точное название;
6. тип Telegram-диалога;
7. словарь и ключевые слова;
8. необязательный анализ последних сообщений.

Правило содержит ID, версию, область действия, priority, condition, target folder и explanation. Поддерживаются chat ID, username, точное название, regex, тип, ключевые слова, язык, unread и ручные списки.

Правила версионируются. Они не удаляют ручные назначения без отдельного подтверждения. Конфликт правил одинакового приоритета отправляет диалог в «Конфликты» и показывает все сработавшие правила.

`condition_json` проходит schema validation. Regex ограничиваются по длине, числу операций и времени выполнения; используется RE2-совместимый или иной timeout-safe engine. Порядок tie-break детерминирован, а изменения правил журналируются.

## 10. Flow синхронизации

### 10.1. Анализ

Модуль проверяет сессию и account ID, получает лимиты и папки, сохраняет read-only snapshot, постранично импортирует диалоги с cursor и явным условием завершения, сохраняет type-aware peer reference, применяет исключения и правила, рассчитывает confidence/explanation и строит immutable analysis snapshot.

Canonical snapshot имеет версию и детерминированный JSON. Он включает account ID, порядок папок, все filter flags и include/exclude vectors, ownership fingerprints, entitlement/лимиты, peer references, версии правил и алгоритма нормализации. `source_hash` — hash этого canonical snapshot, а `plan_fingerprint` — hash нормализованного плана.

`peer_id` хранится вместе с `peer_kind` и актуальной InputPeer reference/access hash. Перед apply недоступный или устаревший peer заново разрешается; при невозможности — переводится в `stale/conflict`, без попытки записи.

До подтверждения запрещены `messages.updateDialogFilter` и `messages.updateDialogFiltersOrder`.

### 10.2. Применение

Перед применением модуль повторно получает состояние папок, порядок, лимиты и entitlement и сравнивает их с canonical snapshot. При несовпадении строится новый diff; merge или ограниченное обновление выполняется только после явного подтверждения, а не по умолчанию.

Изменения применяются последовательно и только при account-scoped lease с concurrency=1. До RPC в БД сохраняется неизменяемый `operation_step` с request fingerprint, precondition fingerprint и ожидаемым postcondition. Состояния шага: `planned → dispatched → outcome_unknown|confirmed|failed`.

После подтверждённого ответа сохраняется checkpoint. При timeout или обрыве шаг переводится в `outcome_unknown`; модуль сначала перечитывает удалённое состояние и сопоставляет его с ожидаемым postcondition, а не повторяет RPC вслепую. Затем обновляются порядок и фактическое состояние, после чего сохраняются result fingerprints и журнал.

### 10.3. Повторный запуск и откат

Новые диалоги попадают в предложения. Импорт использует cursor/termination semantics; после `updateDialogFilter` выполняется обязательный refetch. Недоступные сущности становятся stale. Управляемые папки не дублируются, ручные назначения сохраняются, чужие изменения не перезаписываются автоматически. Откат строится из последнего подтверждённого snapshot, проверяет ownership и fingerprint и также проходит через новый diff и явное подтверждение.

## 11. Внутренний статус приложения

`telegram_app` предоставляет закрытый endpoint:

```text
GET /internal/ayaya/status
Authorization: Bearer <TELEGRAM_INTERNAL_STATUS_SECRET>
```

Он сообщает состояние приложения, базы данных и key-management без раскрытия account data, session-файлов или секретов. Доступность Telegram отражается как component status: временная недоступность Telegram — `degraded`, отказ БД или ключевого хранилища — `unhealthy`. Состояние авторизации конкретного аккаунта показывается только его пользователю и не публикуется в Core status. `telegram_adapter` преобразует ответ в Adapter Protocol status.

## 12. Хранение данных

Модуль владеет отдельной БД `ayaya_mod_telegram`. Core к ней не подключается.

Минимальные сущности:

- `module_users`: `core_user_id`, `display_name`, `last_seen_at`;
- `telegram_accounts`: `module_user_id`, `telegram_account_id`, `display_name`, `encrypted_session`, `encrypted_api_credentials`, `last_seen_at`;
- `dialogs`: `telegram_account_id`, `peer_kind`, `peer_id`, `input_peer_ref`, `access_hash`, `title`, `username`, `metadata_hash`, `last_seen_at`, `stale_at`;
- `folders`: `telegram_account_id`, `app_folder_id`, `telegram_folder_id`, `title`, `emoji`, `managed_by_app`, `ownership_record`, `mode`, `remote_fingerprint`, `local_revision`;
- `assignments`: `telegram_account_id`, `peer_kind`, `peer_id`, `folder_id`, `source`, `confidence`, `explanation`, `locked`, `updated_at`;
- `rules`: `telegram_account_id`, `rule_id`, `version`, `priority`, `condition_json`, `target_folder_id`, `enabled`;
- `snapshots`: `telegram_account_id`, `snapshot_id`, `kind`, `canonical_version`, `source_hash`, `payload`, `retention_until`, `created_at`;
- `operations`: `telegram_account_id`, `operation_id`, `status`, `before_snapshot_id`, `plan_fingerprint`, `plan`, `created_at`, `completed_at`;
- `operation_steps`: `telegram_account_id`, `operation_id`, `step_id`, `status`, `request_fingerprint`, `precondition_fingerprint`, `expected_postcondition`, `result_fingerprint`, `error_json`, `created_at`, `updated_at`.

Все запросы строятся от `core_user_id → module_user → telegram_account`; account FK обязателен во всех доменных таблицах. Уникальные ограничения включают account ID, например `(telegram_account_id, telegram_folder_id)` и `(telegram_account_id, peer_kind, peer_id)`.

Session и API credentials шифруются envelope encryption с AEAD, versioned key ID и ключом из Docker Secret/KMS. Ключ не хранится в образе, БД или логах; его ротация и отказ при недоступности key store обязательны. Запрещены env/debug dumps с plaintext credentials. Disconnect отзывает Telegram session через предусмотренный Telegram flow и удаляет зашифрованную session/credentials после подтверждения. Коды входа и пароль 2FA не сохраняются.

## 13. Ошибки и ограничения

Модуль должен отдельно обрабатывать неверные credentials, чужую сессию, потерю авторизации, FLOOD_WAIT/rate limit, сетевой обрыв, неизвестный результат RPC, частичный успех, удалённый диалог, смену username, переполнение папки и изменения из другого Telegram-клиента.

Для FLOOD_WAIT очередь ставится на паузу с показом времени ожидания. Фоновый module-owned worker обрабатывает один account последовательно, имеет cancellation boundary и ограниченную retry policy. Сетевой обрыв и `outcome_unknown` проходят reconciliation перед продолжением. Ошибка одного чата или папки не скрывает успешные операции других объектов.

## 14. Приватность и журналирование

- режим анализа сообщений выключен по умолчанию;
- сообщение или его фрагмент никогда не отправляются наружу без отдельного согласия;
- внешняя LLM в первой версии не обязательна и не должна быть зависимостью;
- логи не содержат телефон, API hash, коды входа, session string, токены или полный текст сообщений;
- snapshots, backups и error payloads имеют retention policy, шифруются и redacted от credentials/текста сообщений;
- disconnect удаляет локальные данные аккаунта согласно подтверждённой политике retention;
- фрагменты сообщений, если функция включена, имеют отдельное согласие, ограниченный срок хранения и не попадают в explanation;
- UI показывает активную Telegram-сессию и инструкцию по отзыву через официальный Telegram flow;
- режим «только чтение» запрещает все mutating-вызовы.

## 15. Нефункциональные требования

- анализ 1 000 диалогов не читает полную историю сообщений;
- UI не блокируется во время сетевых операций;
- прогресс отображается по этапам и обработанным объектам;
- любую ещё не отправленную mutating-операцию можно отменить;
- незавершённая операция после перезапуска продолжается только после подтверждения;
- операции идемпотентны через durable operation steps, fingerprints, reconciliation и account-scoped lease;
- на один Telegram account одновременно выполняется не более одной операции;
- даты, лимиты и ошибки локализуются для пользователя;
- App и Adapter не публикуют порты на host в стандартном Compose runtime.

## 16. Интеграция и окружение

Root Compose должен добавить `telegram_app` и `telegram_adapter`, отдельную БД/volume либо выделенную БД в общем PostgreSQL, внутренние secrets и mounted `modules/telegram/module.yml`. Core получает `TELEGRAM_ADAPTER_URL`, `TELEGRAM_ADAPTER_SECRET` и общий с `telegram_app` `TELEGRAM_TRUSTED_IDENTITY_SECRET`; adapter получает `TELEGRAM_INTERNAL_STATUS_SECRET`, URL внутреннего статуса и путь к manifest. Core не получает URL или secret `telegram_app`, кроме секрета подписи trusted identity.

NGINX добавляет маршрут `/m/telegram/` по тому же шаблону, что и `/m/notes/`, с `auth_request`, `proxy_pass_request_headers off`, очисткой spoofed headers и allowlist из семи trusted identity headers, включая HMAC signature. Сеть должна позволять Core↔Adapter, Adapter↔App, NGINX↔App и App↔private MTProto transport только по нужным направлениям; `telegram_app` и `telegram_adapter` не публикуются напрямую.

Регистрация в Core выполняется тем же ручным или локальным registration flow, который используется для других модулей. Автоматическая регистрация и динамическая генерация NGINX-конфигурации в первую версию не входят.

## 17. Acceptance criteria

1. Модуль регистрируется в Core с `module_key: telegram`, валидным manifest и status.
2. `/m/telegram` доступен только после Core authentication и отвергает прямой запрос без trusted headers.
3. Пользователь может авторизовать Telegram account с 2FA, а session-file не покидает `telegram_app`; state-changing browser requests без CSRF отклоняются.
4. В read-only режиме отображаются диалоги, папки и актуальные лимиты.
5. Для каждого назначения видны confidence и причина.
6. До подтверждения не выполняются mutating Telegram API calls.
7. Лимиты не превышаются, Premium не является обязательным условием.
8. Чужие папки и ручные изменения не перезаписываются.
9. Внешнее изменение состояния обнаруживается до применения.
10. Timeout до RPC, timeout после RPC, restart и partial success проходят через `operation_steps` и reconciliation без слепого повтора и дубликатов.
11. Последнюю успешную операцию можно откатить через новый diff и подтверждение.
12. Новые диалоги при повторном запуске появляются в предложениях.
13. В логах отсутствуют credentials, session data и содержимое сообщений.
14. Contract tests проверяют manifest, adapter auth, health/status, Compose exposure, точную network topology и внутренний status endpoint.
15. Два разных module users не видят snapshots, rules, folders, operations или Telegram peers друг друга.
16. Unknown/shared/imported/external-modified filters не изменяются без явного ownership и подтверждения.
17. CI использует MTProto test double с fault injection; живой Telegram проверяется отдельным ручным smoke-test на тестовом аккаунте.
18. Disconnect отзывает сессию и удаляет локальные credentials по подтверждённой retention policy.

## 18. Порядок реализации

1. Bundle, `module.yml`, Adapter Protocol, NGINX/network topology и contract tests.
2. Account-scoped schema, key management, CSRF, trusted identity headers и локальные пользователи.
3. Authorization и read-only import диалогов, папок, peer references и динамических лимитов.
4. Canonical snapshots, правила, ручные назначения, pure planner и diff без writes.
5. Worker, account lease, durable operation steps, reconciliation и fault-injection tests.
6. Apply, ownership checks, external-conflict merge, повторная синхронизация и conservative rollback.
7. Retention/disconnect flow, operational docs и ручной smoke-test на тестовом аккаунте.
8. Опциональный анализ последних сообщений и расширенная аналитика.

## 19. Источники Telegram API

- [Dialog folders](https://core.telegram.org/api/folders)
- [messages.getDialogFilters](https://core.telegram.org/method/messages.getDialogFilters)
- [messages.updateDialogFilter](https://core.telegram.org/method/messages.updateDialogFilter)
- [messages.updateDialogFiltersOrder](https://core.telegram.org/method/messages.updateDialogFiltersOrder)
- [User Authorization](https://core.telegram.org/api/auth)
- [Telegram Premium FAQ](https://telegram.org/faq_premium?setln=en)
