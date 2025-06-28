# Задание:
Долгая инфрастуктурная задача. Нужно развернуть, обслуживать, бекапить и восстанавливать наш любимый гитлаб сервер + раннер + докер реестр. Отчёт после каждого этапа. Желательно не заглядывать вперёд. 

Дано:
3 VM, железный кофниг - 2 ядра, 4 Гб, 50 Гб жесткий диск. Эмулируют физические машины, бекап/восстановление средствами средствами гипервизора запрещён. Ресурсов мало, чтоб быстрее заметить их нехватку.
ОС - Alma + Debian, какую ОСь ставить на какую машину - выбираешь самостоятельно, главное, чтоб были обе.
Версия гитлаба на 1 меньше актуальной.

При решение задачи нужно записывать все ходы - что планировалось, что получилось, какие ошибки появились.

# Решение 2. Автоматизированное

## Этап 1. Планирование и настройка виртуальных машин
Выбираю ОС для серверов:
* GitLab сервер — AlmaLinux.
* Docker-регистри — AlmaLinux.
* GitLab Runner — Debian.

   Причина выбора: AlmaLinux стабилен для сложных долгосрочных сервисов. Debian подходит для CI/CD-агентов из-за его лёгкости.

Железо под каждую единое.
### 1.1. Настройка GitLab сервер (almalinux)
#### 1.1.1. Установка ОС
##### 1.1.1.1. Разметка диска
(проверить после установки ОС можно с помощью lsblk):
 
UPD:
При первом выполнении задания не расписала про разметку. Изначально задала чуть больше места под разделы, чем стандартно, т.к. увидела, что часть места "съедается", как я поняла под системные нужды.
Например, ext4 по умолчанию резервирует 5% под служебные нужды (журнал, inode-таблицы и пр.).

Но как я поняла, то в целом, если я задаю 512мб под /boot, реально доступно будет чуть меньше - и это нормально.

Сделала вывод, что для задач просто важно учитывать, какой реально нужен размер, и если есть четкое требование, чтобы было свободно 4 гб под swap, то размечать так, чтобы было свободно 4 гб под swap (т.е. с запасом).

При втором прохождении сделала так:
* `/boot` -	512мб, ext4	(как я поняла, для /boot всегда лучше ext4 - т.к. grub стабильнее с ним работает, лучше чем с xfs)
* `swap` - 2гб, swap - обычно выделяют 2-4гб	
* `/` - 20гб, ext4 (подходит и ext4, и xfs. как я поняла, ext4 проще в поддержке, а xfs позволяет хранить большие данные, но разница между ними не прямо огромная для обычных разделов) - под системные файлы
* `/var` - все оставшееся место, ext4 - логи bnl. как я поняла, лучше сюда побольше места, т.к. сюда будет много писаться
 
![alt text](image-92.png) 

##### 1.1.1.2. Настраиваю сеть
Здесь ставлю переключатель на вкл + задаю имя сервера
 
**Имя сервера:** `gitlab-server.lan`
> Изначально я все сервера назвала с `.local`, потом при настройке локального DNS столкнулась с проблемой, так как `.local` зарезервирован для Multicast DNS (mDNS), который используется для автоматического обнаружения устройств в локальной сети (например, Avahi в Linux). И т.к. использование `.local` для кастомных доменов может привести к конфликтам и проблемам с разрешением имен, то как альтернативу взяла `.lan`
 
![alt text](image-93.png)
 
##### 1.1.1.3. Выбираю минимальный вариант установки ОС
 
![alt text](image-94.png)

##### 1.1.1.4. Ставлю время
UPD: оно у меня на альме слетает от случая к случаю. Во второе прохождение не слетало.
  
![alt text](image-95.png)

##### 1.1.1.5. Задаю пароль руту и создаю админа
UPD: В первое прохождение админа создавала после установки ОС, сейчас решила сразу на этапе установки ОС
 
![alt text](image-97.png)

#### 1.1.2. После установки ОС настраиваю машинку.
 
**1.1.2.1. Тип подключения к сети:** Bridge
 
**1.1.2.3. Проверяю, что SSH стоит (на Альме, как и на Центос должен стоять по умолчанию):**
```bash
sudo systemctl status sshd
```
Стоит:
![alt text](image-151.png)
 
**1.1.2.3. Узнаю адрес машины для подключения по SSH**
```bash
ip addr
```
(дальше все с подключение по SSH)
![alt text](image-150.png)

**1.1.2.4. Узнаю хостнейм**
UPD: При первом прохождении он некорректно настроился. При втором прохождении проверяю, все ли ок, надо ли менять:
```bash
hostname
```

Все корректно:
 
![alt text](image-148.png)

При этом помним, что в `/etc/hosts` оно не добавляется автоматически, надо позже добавить, когда буду настраивать локальный днс. В целом, нестрашно, что не добавляется, т.к. в проде предполагается, что днс настроен централизованно. Так что это важно только в рамках задания
 
**1.1.2.5. Проверяю, какой используется сетевой менеджер**
Должен быть один из этих:
* NetworkManager
* systemd-networkd
* networking
 
 Проверяю первый:
```bash
systemctl is-active NetworkManager
```
 
![alt text](image-149.png)
Отлично, иду дальше
 
**OLD 1.1.2.6 - Настройка статического IP-адреса. Уношу в автоматизацию**
UPD: Делала при первом прохождении (вручную), сейчас уношу в автоматизацию
  
**OLD 1.1.2.7 - Настройка хостнейма. Уношу в автоматизацию**
UPD: Делала при первом прохождении (вручную), сейчас уношу в автоматизацию
 
### 1.2. Настройка Docker-регистри (almalinux)
По сути все то же, что и при настройке гитлаб-сервера. При втором прохождении тоже пошла чуть по другому пути. Описала, но отличия только в имени хоста
##### 1.2.1.2. Настраиваю сеть
Здесь ставлю переключатель на вкл + задаю имя сервера
 
**Имя сервера:** `docker-registry.lan`
**Проверяю, что SSH стоит (на Альме, как и на Центос должен стоять по умолчанию):**
```bash
sudo systemctl status sshd
```
Стоит:
![alt text](image-152.png)
 
**Узнаю адрес машины для подключения по SSH**
```bash
ip addr
```
(дальше все по SSH)
![alt text](image-153.png)

**Узнаю хостнейм**
UPD: При первом прохождении он некорректно настроился. При втором прохождении проверяю, все ли ок, надо ли менять:
```bash
hostname
```

Все корректно:
 
![alt text](image-160.png)

При этом помним, что в `/etc/hosts` оно не добавляется автоматически, надо позже добавить, когда буду настраивать локальный днс. В целом, нестрашно, что не добавляется, т.к. в проде предполагается, что днс настроен централизованно. Так что это важно только в рамках задания
 
**Проверяю, какой используется сетевой менеджер**
Должен быть один из этих:
* NetworkManager
* systemd-networkd
* networking
 
 Проверяю первый:
```bash
systemctl is-active NetworkManager
```
![alt text](image-161.png)
 
**OLD 1.1.2.6 - Настройка статического IP-адреса. Уношу в автоматизацию**
UPD: Делала при первом прохождении (вручную), сейчас уношу в автоматизацию
  
**OLD 1.1.2.7 - Настройка хостнейма. Уношу в автоматизацию**
UPD: Делала при первом прохождении (вручную), сейчас уношу в автоматизацию
 
### 1.3. Настройка GitLab Runner (debian)
#### 1.3.1. Установка ОС
UPD: Обновила решение. Добавила просто картинками по моментам, которые посчитала основными. В качестве локации выбрала РФ, для клавиатуры оставила англ.
 
![alt text](image-98.png)
 
Задаю хостнейм - gitlab-runner.lan:
 
![alt text](image-99.png)
 
Создаю пользователя второго:
 
![alt text](image-101.png)
 
Тоже задаю время (которое потом не слетает, кстати):
 
![alt text](image-102.png)

Ручная разметка диска:
 
![alt text](image-103.png)

Выбираю диск для разметки (выбираю, громко сказано, т.к. он один)
 
![alt text](image-104.png)

Создаю новую таблицу разделов:
 
![alt text](image-105.png)

Два раза жамкаю в свободное место:
 
![alt text](image-116.png)

Выбираю создание нового раздела (начну с /boot):
 
![alt text](image-117.png)
 
Выделяю место:
 
![alt text](image-118.png)

Выбираю тип раздела (как я поняла, для /boot всегда лучше primary)
 
![alt text](image-119.png)

Выбираю, что раздел стоит разместить в начале диска (как я поняла, на современных системах без разницы, но по канону пусть будет в начале):
 
![alt text](image-120.png)

Выбрала точку монтирования /boot + поставила флаг загрузки на on (для биос), остальное не трогала:
 
![alt text](image-121.png)

Подтверждаю выбор:
 
![alt text](image-123.png)

Дальше перехожу к настройке LVM. Выбираю оставшееся свободное место:
 
![alt text](image-125.png)

Выбираю создать новый раздел:
 
![alt text](image-124.png)

Выделяю все оставшееся место:
 
![alt text](image-126.png)

Так же выбираю primary
 
![alt text](image-127.png)

В разделе use as выбираю как том под lvm
 
![alt text](image-128.png)

И подтверждаю
 
![alt text](image-129.png)

Попадаю в +- общее меню и выбираю настройку lvm
 
![alt text](image-130.png)

Подтверждаю запись текущей схемы разделов на диск:
 
![alt text](image-131.png)
 
Создаю volume group:
 
![alt text](image-132.png)

Задаю имя. Можно любое, пусть vg-debian:
 
![alt text](image-106.png)

Далее выбираю устройства, которые будут использованы для новой volume group. Отмечаю только /dev/sda2, потому что /dev/sda1 уже используется под /boot и не должен попадать в volume group.
Итого, сейчас создаю volume group, которая может объединить несколько физических дисков в единое пространство. А потом уже поверх этого единого пространства буду строить логические тома для lvm:
 
![alt text](image-107.png)

Теперь, собсвтенно, создаю логический том внутри vg:
![alt text](image-108.png)
 
Дальше выбираю volume group, в которой будут создаваться логические тома. У меня доступна только одна vg — vg-debian, поэтому выбираю ее. 
 
![alt text](image-109.png)
 
Начну со свап. Задаю имя:
 
![alt text](image-110.png)

Размер для свап:
![alt text](image-111.png)

То же самое под корневой раздел:
 
![alt text](image-112.png)
![alt text](image-113.png)
![alt text](image-114.png)
![alt text](image-115.png)

И то же самое под /var:
 
![alt text](image-133.png)
![alt text](image-134.png)
![alt text](image-135.png)
![alt text](image-136.png)

Все lvm подготовила, выхожу:
 
![alt text](image-137.png)

Настраиваю каждый lvm.

Сперва корень (ext4, точка монтирования - /):
 
![alt text](image-138.png)
![alt text](image-139.png)

Затем свап (в use as указываю swap):
 
![alt text](image-140.png)
![alt text](image-141.png)

Затем /var (ext4, точка монтирования - /var):
 
![alt text](image-142.png)
![alt text](image-143.png)

Все настроила, выхожу:
 
![alt text](image-144.png)

Подтверждаю изменения:
 
![alt text](image-145.png)
 
В блоке software убрала gui, добавила ssh:
 
![alt text](image-146.png)

На этапе выбора места для загрузчика выбираю /dev/sda (по умолчанию предлагал вручуню указать):
 
![alt text](image-147.png)

Все остальное по умолчанию

#### 1.3.2. После установки ОС настраиваю машинку.

**1.3.2.1.Тип подключения к сети:** Bridge

**1.3.2.2. При установке ОС уже создала пользователя, добавляю его в sudo:**
Т.к. сейчас я под рутом, то делаю просто:
```bash 
usermod -aG sudo kaya
```
 
При первом прохождении авторизовалась под юзером и делала так:
```bash
su -    
usermod -aG sudo kaya
exit  
id kaya     
newgrp sudo
```
 
**1.3.2.3. Проверяю, наличие SSH**
```bash
sudo systemctl status ssh
```
Стоит: 
![alt text](image-154.png)
 
P.S. При первом прохождении не было, т.к. не отметила галочку при установке, выбрала все по минимуму, а на дебиан SSH по умолчанию не стоит.
 
**OLD 1.3.2.4. Обновляю систему и устанавливаю OpenSSH Server:**
 <details>
  <summary>Посмотреть</summary>
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install openssh-server -y
sudo systemctl status ssh
```
</details>

**1.3.2.5. Узнаю IP для дальнейшего подключения**
```bash
ip addr
```
(дальше все тоже по SSH)
![alt text](image-155.png)
 
**1.3.2.6. Также, узнаю, какой менеджер сети используется**
```bash
systemctl is-active NetworkManager
```
Нет:
![alt text](image-157.png)

```bash
systemctl is-active systemd-networkd
```
Тоже нет:
![alt text](image-158.png)
 
```bash
systemctl is-active networking
```
Моя остановочка:
![alt text](image-156.png)

**OLD 1.3.2.7. - Настраиваю статический IP**
UPD: Делала при первом прохождении (вручную), сейчас уношу в автоматизацию
 
**1.3.2.9. Проверка hostname**
```bash
hostname
```
![alt text](image-159.png)

**1.3.2.10. - Настройка хостнейма:**
> UPD: Делала при первом прохождении. И делаю при втором. При первом прохождении выполнила, т.к. я сперва использовала `.local`, вместо `.lan`. Сейчас делаю, т.к. при просмотре имени хоста (команда выше) нет `.lan`.
Узнала, что у альмы и дебиан разное поведение системы при задании хостнейма:
* В альме при установке хостнейм с доменом (например, `gitlab-server.lan`), он сохраняется полностью в `/etc/hostname` и `hostnamectl`.
* в дебиан по умолчанию сохраняется только короткое имя хоста (например, `gitlab-runner`), а домен `.lan` предполагается прописывать отдельно в /etc/hosts. 
Поэтому на дебиан привожу всё к единому виду: задаю хостнейм с доменом (gitlab-runner.lan). Чтобы в будущем не было проблем при настройке сети, разрешении имён и подключении по ssh.
 
```bash
sudo hostnamectl set-hostname gitlab-runner.lan
```
 
<details><summary>Старое и неправильное</summary>
Раньше меняла запись а `/etc/hosts`, но зря. Пояснение от Юры:
> Коммент от Юры:
> Вся сеть 127...* локальная.
> Файл hosts используется для резолва статичных имён.
> В итоге при запросе имени с самого себя попадёт на локальную петлю, без необходимости ходить на какой-то интерфейс. 

Делала так. Выполнила
```bash
sudo nano /etc/hosts
```
![alt text](image-33.png)
И заменила
```bash
127.0.1.1    gitlab-runner.local gitlab-runner
 ```
  
на 
```bash
172.20.10.5    gitlab-runner.lan gitlab-runner
```
 
> Тут у меня возник вопрос к 127.0.1.1. Как я поняла, В Debian и его производных используется IP-адрес 127.0.1.1 для привязки локального доменного имени к IP 127.0.1.1. Обычно, если gitlab-runner только локальное имя, это нормально. Однако, если это сервер в сети с другим IP, надо заменить IP-адрес на актуальный 
 </details>
 
**1.3.2.11. - Установка sudo (optional)**
При втором прохождении sudo не было.
Добавила. Зашла на сервер под root и выполнила:
 
apt install sudo
usermod -aG sudo kaya
 

###  Optional: 1.4. Настройка статического адреса на windows
UPD: Во время второго прохождения не делала.
 
>  Optional - т.к. неудобно с локальным адресом на ноуте. Особенно, если с него подключаться к разным сетям. Костыль, который иногда нужен, иногда нет
 
> Этот пункт внесла не сразу. Все работало хорошо, потом не могла подключиться к гитлаб-серверу по SSH - ошибка "connection refused". Крутила, вертела, поняла, что на windows выдался тот же ip. И решила, что чем постоянно менять адрес на виртуалке (который итак уже задан), сделаю статику и на винде.

Открываю Панель управления -> Сеть и Интернет -> Центр управления сетями и общим доступом -> Изменение параметров адаптера (в меню слева).
Нахожу активный адаптер -> ПКМ -> Свойства:
![alt text](image-65.png)

Выбираю IP версии 4 -> Свойства
![alt text](image-66.png)

Заполняю:
![alt text](image-79.png)

* Открываю повершел и ввожу команду `ipconfig /all`, там нахожу заголовок "Адаптер беспроводной локальной сети Беспроводная сеть:", оттуда узнаю, как заполнить **маску подсети**, **основной шлюз** и **DNS-серверы**
* Чтобы узнать, какой мне доступен диапазон адресов, смотрю на маску подсети, т.к она определяет диапазон ip адресов входящих в подсеть. Если раньше я брала выданный адрес и просто его делала статическим, то сейчас надо сменить адрес на другой. Моя маска - **255.255.255.240**, поискала, как с этим работать. В поисках нашла прикольный калькулятор, на котором можно себя проверить: https://infocisco.ru/ip_calculator.php. 
* В общем из 14 доступных адресов (чуть меньше, т.к. уже 3 под ВМ отдала, выбрала свободный)
* Перезапускаю сетевой адаптер и делаю `ipconfig /all` в повершелл, чтобы убедиться, что все ок
* Да, потом для выхода "в свет" скидываю на автоматическую выдачу ip


### Optional: 1.5. Настройка времени на серверах с АльмаЛинукс
>  Optional - т.к. работает по разному. При втором прохождении у меня все ок со временем, не понадобилось. Встречала на центос и на альме.
При установке могут быть проблемы с временем из-за недоступности NTP-серверов. Решается добавлением серверов в /etc/chrony.conf и перезапуском службы. На дебиан таких проблем не встретила.
 
Проверим время в системе:
```bash
timedatectl status
```
 
В выводе снова `NTP synchronized: no` говорит, что служба синхронизации времени не работает.
 
Проверим статус службы синхронизации времени:
```bash
sudo systemctl status chronyd
```
 
Судя по статусу, chronyd работает, но синхронизации времени все равно нет. У меня снова дело в том, что NTP-сервера недоступны. 
 
Открываем конфиг:
```bash
sudo nano /etc/chrony.conf
```
 
Добавим туда следующие сервера:
```bash
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst
```
 
Сохраним изменения и перезапустим Chrony:
```bash
sudo systemctl restart chronyd
```
 
После настройки серверов принудительно синхронизируем время:
```bash
sudo chronyc -a makestep
```
 
1.1.7. Снова проверим состояние времени:
```bash
timedatectl status
```
 
Ура, все ок. В отличие от центос на альме сразу все обновляется (центос было нужно немного времени)
 
### Optional: 1.6. Оставить в загрзочных устройствах на ВМ только жесткий диск
UPD: при втором прохождении добавила перезагрузку ВМ в плейбуки. Иногда срабатывало нормально, иногда зависало на том, что ВМ хотела загрузиться с CD, а там было пусто.
Поэтому оставила только жесткий диск, чтобы большого такого не было:
![alt text](image-166.png)

### 1.7. Настройка файла hosts для разрешения имен на хосте с Windows
 
На ноуте не стала настраивать DNS, чтобы не менять системные параметры.  
Вместо этого добавляю имена вручную в файл `hosts`.
1. Пуск → Поиск → Блокнот → ПКМ → Запуск от имени администратора
2. В блокноте открываю путь `C:\Windows\System32\drivers\etc\`
3. Выбираю тип файла "Все файлы"
4. Из появившегося списка выбираю `hosts`
5. Вставляю строки:
```bash
172.20.10.2    gitlab-runner.lan
172.20.10.3    gitlab-server.lan
172.20.10.4    docker-registry.lan
```
6. Сохраняю
 
## Этап 2. Автоматизация первого решения
Как вижу решение:
1) Bootstrap-плейбук (автоматизация всего того, что в первом решении делала вручную - т.е. базовая настройка всех серверов):
* Синхронизация времени
* Настройка статического IP
* Установка и настройка dns на сервере gitlab-runner (можно как dnsmasq, так и /etc/hosts. при первом прохождении настраивала dnsmasq, сейчас выбрала /etc/hosts)
 
2) Второй плейбук — основное решение задания
 
### 2.2.1. Установка Ansible на WSL (Ubuntu)
Открываю WSL и обновляю пакеты:
```bash
sudo apt update && sudo apt upgrade -y
```
 
Устанавливаю Ansible:
```bash
sudo apt install ansible -y
```
 
Проверяю, что Ansible установлен и работает:
```bash
ansible --version
```
![alt text](image-76.png)

 <details>
  <summary>Ремарка про версию ансибл</summary>
Я до этого смотрела разные версии ansible и к моменту второго прохождения задания у меня стояла ansible [core 2.17.12]
 
При запуске роли common столкнулась с ошибкой, что при использовании модуля yum на серверах с альмалинукс выскакивало:
```bash
SyntaxError: future feature annotations is not defined
```
 
Я думала, что проблема в устарешем питоне на серверах, но на них стоял свежий питон (версия 3.11) и зависимости. 

Как я поняла, истинная причина была такой:
Дело в Ansible 2.17, он ломается, пытаясь использовать свой же модуль на Python 3.11 в zip-виде:
- эта версия отправляет модули в zip-архивах на удалённые машины
- внутри zip-архивов есть файлы с конструкцией `from __future__ import annotations`
- такая конструкция не работает при выполнении zip-архива через stdin в Python 3.11 
 
Я решила его поставить через pip:
 
1. Удалила текущий ансибл 
```bash
sudo apt remove --purge ansible -y
sudo apt autoremove -y
```
 
2. Установила pip, venv
```bash
sudo apt update
sudo apt install python3-pip python3-venv -y
```
 
Создала виртуальное окружение, чтобы изолировать ансибл и его зависимости:
```bash
python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate
```
 
Установила:
```bash
pip install ansible-core==2.15.9
pip install ansible==7.5.0
```

Вроде как:
- ansible-core 2.15.9 — последняя версия без проблем с future annotations в zip-модулях
- ansible==7.5.0 — включает нужные коллекции, совместим с этим ядром
 
Проверка, что все ок:
```bash
ansible --version
```
 
Как я поняла,  нужно удалить кэш старых zip-модулей, которые могли остаться после ансибл 2.17.
```bash
rm -rf ~/.ansible/tmp/*
rm -rf ~/.ansible/facts/cache/*
```
 
Создала симлинк, чтобы активировать окружение из любой директории командой `source venv/bin/activate` 
```bash
ln -s ~/ansible-venv ./venv
```
</details>
 

### 2.2.2. Настройка на серверах SSH-доступа без пароля
> На серверах настроим вход по SSH без пароля - через ключи. Так удобнее и безопаснее + чтобы при масштабировании проекта ансибл мог подключаться ко всем серверам автоматически, без запроса пароля вручную при каждом подключении.
> Для этого на клиенте (в моем случае - WSL) должна быть пара ключей (приватный + публичный). Публичный добавляю на сервера, к которым буду подключаться.

Проверяю, что на серверах установлен OpenSSH Server (ну выше я ставила, но это так, для общей инструкции больше)
```bash
sudo systemctl status sshd
```
 
Проверяю, есть ли ключи на WSL:
```bash
ls ~/.ssh
```
 
У меня ключи есть (если бы не было, надо создать с помощью команды `ssh-keygen -t rsa -b 4096 -C "коммент, напр. почта"`)
![alt text](image.png)
 
Копирую публичный ключ на серверы. На каждой машине, к которой мы будем подключаться по SSH без пароля, надо разместить публичный ключ в `~/.ssh/authorized_keys`.
Можно вручную скопировать и вставить, можно на WSL с помощью команд:
```bash
ssh-copy-id kaya@172.20.10.2
ssh-copy-id kaya@172.20.10.3
ssh-copy-id kaya@172.20.10.4
```
 
* Использую `ssh-copy-id`, т.к. сейчас на серверах включён парольный доступ по SSH. Если на целевой сервер по паролю не подключиться, то добавлять ключи надо, конечно же, не так, например, руками
* При втором прохождении обращалась к серверам по адресам, т.к. еще не настроила статические + dnsmasq
 
### 2.2.3. Настройка инвентаря ансибл
Создаю каталог под проект:
```bash
mkdir -p /home/kaya/ansible-projects/rockot-it-tasks/task_6 && cd /home/kaya/ansible-projects/rockot-it-tasks/task_6
```
 
### 2.2.3.1. Бутстрап этап
Создаю инвентарь:
```bash
nano inventory.ini
```
> Он у меня единый для бутстрап этапа и для основного. Поэтому его в корне делаю
 
В инвентаре указываю две группы серверов по ip адресам. IP заполняю на основе команды ip addr на самих серверах, имена оставляю себе для ориентации:
```bash
[servers_on_almalinux]
gitlab-server ansible_host=172.20.10.3
docker-registry ansible_host=172.20.10.4

[servers_on_debian]
gitlab-runner ansible_host=172.20.10.2

[all:vars]
ansible_user=kaya
ansible_ssh_private_key_file=/home/kaya/.ssh/id_rsa
```
 
> Я прописала три сервера и единые переменные для всех хостов - имя пользователя и приватный ключ `~/.ssh/id_rsa` для аутентификации по SSH.
> 
> Из любопытного, наткнулась, что не всегда `~` в ансибл корректно распознается, и поэтому лучше писать абсолютный путь, поэтому прописала `/home/kaya/`.
  
Проверяю, что Ansible может подключиться к серверам:
```bash
ansible all -i inventory.ini -m ping
```
 
Вывод:
 
![alt text](image-162.png)

Главное, что нет серверов в статусе unreacheble. Получаю ошибку: на серверах с альмалинукс установлен только системный питон, а пользовательского нет. Т.к. системный использовать не рекомендуется, то ансибл ругается, что питона нет.
Он нужен, т.к. ансибл для работы по умолчанию использует модули, написанные на питоне, и  поэтому при отсутствии питона он просто не сможет выполнять эти задачи.

Для бутстрап этапа я нашла raw-модуль, который работает без питона — это фактически "голый" SSH: отправь команду и получи вывод.

Сейчас все настрою, а пока в инвентарь для будущих задач пропишу, где брать питон. Пропишу сразу для альмалинукс и для дебиан, чтобы было чище.
> Спойлер, если установить питон из стандартного репозитория, он поставит версию 3.6, и позже будет ругаться, что для работы модулей ансибл нужна версия постарше. Поэтому ниже в бутстрап-плейбуке я ставлю конкретную версию 3.11 и прописываю ее в инвентаре.
 
```bash
[all:vars]
ansible_python_interpreter=/usr/bin/python3.11
```
 
![alt text](image-165.png)

Дальше. Настройка плейбука
 
### 2.2.3.2. Создаю бутстрап-плейбук 
Как я поняла, в бутстрап-плейбуке роли не нужны, т.к.:
* он выполняется один раз при инициализации системы
* он во многом зависит от конкретной архитектуры
 
Создаю плей:
```bash
nano bootstrap-playbook.yml
```
 
Наполняю
```yml
---
- name: Настройка серверов (bootstrap)
  hosts: all
  become: true
  gather_facts: false

  tasks:

    - name: Проверить наличие Python на сервере
      raw: |
        which python3.11 || python3.11 --version
      register: python_check
      changed_when: false
      failed_when: false

    - name: Вывести результат проверки Python
      debug:
        msg: >-
          {% if python_check.rc == 0 %}
          На сервере {{ inventory_hostname }} уже установлен Python 3.11
          {% else %}
          На сервере {{ inventory_hostname }} Python 3.11 не найден — будет установлен
          {% endif %}

    - name: Установить Python 3.11 и нужные pip-зависимости
      raw: |
        if [ -f /etc/redhat-release ]; then
          yum install -y epel-release
          yum install -y python3.11 python3.11-pip
          python3.11 -m pip install --upgrade pip
          python3.11 -m pip install selinux cryptography PyYAML distro six
        elif [ -f /etc/debian_version ]; then
          apt-get update
          apt-get install -y python3.11 python3.11-distutils python3.11-venv python3.11-pip
          python3.11 -m pip install --upgrade pip
          python3.11 -m pip install selinux cryptography PyYAML distro six
        fi
      when: python_check.rc != 0

    - name: Получить версию Питон после установки
      raw: python3 --version || python --version
      register: python_version
      changed_when: false

    - name: Дебаг - Вывод версии установленного Питон
      debug:
        msg: "Версия Python на сервере {{ inventory_hostname }}: {{ python_version.stdout | replace('\r', '') | replace('\n', '') | trim }}"

    - name: Собрать факты после установки Python
      setup:

    - name: Настройка статического IP на Альмалинукс
      community.general.nmcli:
        conn_name: enp0s3
        ifname: enp0s3
        type: ethernet
        ip4: "{{ static_ip_map[inventory_hostname].address }}/{{ default_cidr }}"
        gw4: "{{ default_gateway }}"
        dns4: "{{ default_dns }}"
        state: present
      when: ansible_os_family == 'RedHat'

    - name: Активировать соединение enp0s3 после настройки
      command: nmcli con up enp0s3
      when: ansible_os_family == 'RedHat'

    - name:  Настройка статического IP на Дебиан (перезапись /etc/network/interfaces)
      ansible.builtin.copy:
        dest: /etc/network/interfaces
        content: |
          source /etc/network/interfaces.d/*

          auto lo
          iface lo inet loopback

          auto enp0s3
          iface enp0s3 inet static
              address {{ static_ip_map[inventory_hostname].address }}/{{ default_cidr }}
              netmask {{ default_netmask }}
              gateway {{ default_gateway }}
              dns-nameservers {{ default_dns }}
        mode: '0644'
      when: ansible_os_family == 'Debian'

    - name: Перезагрузка сервера Дебиан для применения изменений
      ansible.builtin.reboot:
        reboot_timeout: 300
      when:
        - ansible_os_family == 'Debian'
      tags: reboot

    - name: Проверка IP-адреса интерфейса enp0s3
      command: ip addr show enp0s3
      register: ip_check
      changed_when: false

    - name: Дебаг - IP интерфейса enp0s3
      debug:
        var: ip_check.stdout

    - name: Вывод — динамический или статический IP на серверах
      debug:
        msg: >-
          {% if 'dynamic' in ip_check.stdout %}
          На интерфейсе enp0s3 используется динамический IP (DHCP)
          {% else %}
          На интерфейсе enp0s3 используется статический IP
          {% endif %}

    - name: Обновление /etc/hosts на всех серверах
      blockinfile:
        path: /etc/hosts
        marker: "# {mark} ANSIBLE MANAGED BLOCK - LAN HOSTS"
        block: |
          {% for key, params in static_ip_map.items() %}
          {{ params.address }} {{ params.fqdn }} {{ params.hostname }}
          {% endfor %}

    - name: Перезагрузка сервера всех серверов для применения изменений
      ansible.builtin.reboot:
        reboot_timeout: 300
      when:
      tags: reboot

    - name: Проверка доступности gitlab-server.lan
      ansible.builtin.command: getent hosts gitlab-server.lan
      register: dns_check_gitlab
      changed_when: false

    - name: Проверка доступности docker-registry.lan
      ansible.builtin.command: getent hosts docker-registry.lan
      register: dns_check_registry
      changed_when: false

    - name: Проверка доступности gitlab-runner.lan
      ansible.builtin.command: getent hosts gitlab-runner.lan
      register: dns_check_runner
      changed_when: false

    - name: Дебаг - Проверка резолвинга имён
      debug:
        msg: |
          GitLab: {{ dns_check_gitlab.stdout }}
          Registry: {{ dns_check_registry.stdout }}
          Runner: {{ dns_check_runner.stdout }}
```
> Примечание:
> * Изначально ставила питон на альмалинукс из оф. репозиториев командой `yum install -y python3`, но ставился питон 3.6 и ансибл ругался, что версия питона слишком старая, модули не могут выполниться, поэтому ставила из epel-release
> 
 
Создаю директорию и файл для переменных:
```bash
mkdir group_vars && nano group_vars/all.yml
```
 
Наполняю:
```yml
default_gateway: 172.20.10.1
default_netmask: 255.255.255.240
default_dns: "8.8.8.8 1.1.1.1"
default_cidr: 28

static_ip_map:
  gitlab-server:
    fqdn: gitlab-server.lan
    hostname: gitlab-server
    address: 172.20.10.3

  docker-registry:
    fqdn: docker-registry.lan
    hostname: docker-registry
    address: 172.20.10.4

  gitlab-runner:
    fqdn: gitlab-runner.lan
    hostname: gitlab-runner
    address: 172.20.10.2
```
 
### 2.2.3.3. Тестирую бутстрап-плейбук
Запускаю бутстрап-плейбук:
```bash
ansible-playbook -i inventory.ini bootstrap-playbook.yml --ask-become-pass
```
Примечание: пока тестировала бутстрап-плейбук, в один из разов не смогла запустить его так. Помогла команда
```bash
ANSIBLE_SSH_PIPELINING=false ansible-playbook -i inventory.ini bootstrap-playbook.yml --ask-become-pass 
```
 
Вывод:
 
![alt text](image-167.png)
 
### 2.2.4. Создаю структуру ролей
 
Создаю структуру ролей:
```bash
cd /home/kaya/ansible-projects/rockot-it-tasks/task_6
ansible-galaxy init roles/common
ansible-galaxy init roles/docker
ansible-galaxy init roles/gitlab_server
ansible-galaxy init roles/gitlab_runner
ansible-galaxy init roles/docker_registry
ansible-galaxy init roles/postfix
```
> Роль common создала не сразу. Опять слетело время. Так как это иногда случается, то пусть будет отдельная роль на такие случаи, ну и мб потом пригодятся настройки какие.
 
> Для памятки: после команд у нас создались соответствующие директории с единой структурой. Посмотреть можно с помощью `tree roles`:
>  ![alt text](image-80.png)

Пока роли пустые, буду наполнять по одной: наполнила, протестировала, пошла дальше. Чтобы потом не было всего в куче. 
 
### 2.2.5. Создаю основной плейбук 

Создаю плей:
```bash
nano playbook.yml
```
 
Наполняю
```yml
---
- name: Базовая настройка серверов (время, в будущем, может, что-то еще)
  hosts: all
  become: true
  roles:
    - common
  tags: common

- name: Установка докера на все серверы
  hosts: all
  become: true
  roles:
    - docker
  tags: docker

- name: Поднимаем гитлаб-сервер в докер-контейнере 
  hosts: gitlab-server
  become: true
  roles:
    - role: gitlab_server
      tags: gitlab_server

- name: Поднимаем гитлаб-раннер в докер-контейнере
  hosts: gitlab-runner
  become: true
  roles:
    - gitlab_runner
  tags: gitlab_runner

- name: Поднимаем докер-регистри в докер-контейнере
  hosts: all
  become: true
  roles:
    - docker_registry
  tags: docker_registry
```
 
> Для каждой роли прописала тег, чтобы можно было запускать каждую роль по отдельности для отладки. Можно было бы прописать несколько тегов в квадратных скобках, но пока не придумала уместную для задачи ситуацию.
> 
> Кстати, я попутно узнала, что для ролей все пишут вместо пробелов нижнее подчеркивание, а для имен серверов в инвентори пишут дефис.
> Для гитлаб сервера сперва прописывала установку postfix, т.к. делала так в первом решении. Но в первом решении это архаизм, т.к. сперва я ставила гитлаб без докер контейнера. При установке в докер-контейнере все необходимое уже внутри есть, так что убрала

### 2.2.6. Роль common
#### 2.2.6.1. Создаю роль для базовой настройки системы
 
```bash
nano roles/common/tasks/main.yml
```
 
После
```yml
---
# tasks file for roles/common
```
 
Вставляю
```yml
# Настройка времени для ОС на базе RedHat
- name: Настройка времени для ОС на базе RedHat
  when: ansible_os_family == "RedHat"
  block:
    - name: Проверка наличия chrony
      yum:
        name: chrony
        state: present
        update_cache: yes

    - name: Настройка NTP-серверов в конфиге /etc/chrony.conf
      blockinfile:
        path: /etc/chrony.conf
        marker: "# {mark} ANSIBLE MANAGED NTP BLOCK"
        block: |
          server 0.pool.ntp.org iburst
          server 1.pool.ntp.org iburst
          server 2.pool.ntp.org iburst
          server 3.pool.ntp.org iburst

    - name: Перезапуск chronyd после изменения конфигурации
      service:
        name: chronyd
        enabled: true
        state: restarted

    - name: Принудительная синхронизация времени
      command: chronyc -a makestep
      register: chronyc_result
      changed_when: "'step' in chronyc_result.stdout"

    - name: Ждём, пока chronyd догонит (максимум 5 попыток)
      command: chronyc tracking
      register: chrony_tracking_status
      changed_when: false
      until: chrony_tracking_status.stdout is search('Leap status\s*:\s*Normal')
      retries: 5
      delay: 5

    - name: Дебаг - вывод ошибки, если время не синхронизировано (Leap status)
      fail:
        msg: "Время не синхронизировано: в выводе chronyc tracking — Leap status: НЕ Normal"
      when: chrony_tracking_status.stdout is not search('Leap status\s*:\s*Normal')

    - name: Дебаг - вывод сообщения, что все ок, если время синхронизировано (Leap status)
      debug:
        msg: "Время синхронизировано: в выводе chronyc tracking — Leap status: Normal"
      when: chrony_tracking_status.stdout is search('Leap status\s*:\s*Normal')

# Настройка времени для ОС на базе Debian
- name: Настройка времени для ОС на базе Debian
  when: ansible_os_family == "Debian"
  block:
    - name: Отключаем синхронизацию времени
      command: timedatectl set-ntp false

    - name: Ждём 1 секунду
      pause:
        seconds: 1

    - name: Включаем синхронизацию времени
      command: timedatectl set-ntp true

    - name: Проверка, есть ли синхронизация времени (NTPSynchronized)
      command: timedatectl show -p NTPSynchronized --value
      register: ntp_synchronized_status
      changed_when: false

    - name: Дебаг - вывод ошибки, если время не синхронизировано (NTPSynchronized)
      fail:
        msg: "timedatectl: Время НЕ синхронизировано — NTPSynchronized: no"
      when:
        - ntp_synchronized_status.stdout != "yes"

    - name: Дебаг - вывод сообщения, что все ок, если время синхронизировано (NTPSynchronized)
      debug:
        msg: "timedatectl: Время синхронизировано — NTPSynchronized: yes"
      when:
        - ntp_synchronized_status.stdout == "yes"
```
> По порядку про интересности:
> 1. Узнала про маркеры в blockinfile. Выглядит удобно - при повторном запуске плейбука ансибл не будет дублировать блок в рамках маркера, а еще можно вносить изменения именно в него и удалить, тоже только его. Решила добавить, чтобы захламлять конфиг при повторных прогонах.
> 
> 2. Здесь для Альмы использую `command`, потому что иначе не работает. 
> Я узнала, что:
> * По умолчанию chronyd не делает резкую синхронизацию (jump), если время отличается сильно — чтобы не сломать работу системных сервисов, которые чувствительны к скачкам времени. А на моих ВМ расхождение во времени более чем на месяц. 
> * По умолчанию, если `chronyd` обнаруживает большое расхождение (обычно больше 3 секунд), он переходит в режим "slew" — медленно «подтягивает» время, добавляя или убавляя доли секунд. Это безопасно, но может занять часы или дни, если расхождение большое (вроде месяца).
При этом `chronyd` всё равно считает, что он работает корректно — просто потихоньку выравнивает.
> 
> У меня сервер с нуля, так что сейчас резкий скачок времени ничего не сломает. В реальной среде, я пока не понимаю, как поступить. Думаю, что нужно оценить, насколько большое расхождение во времени; насколько критично сменить его прямо сейчас (или можно подождать); если критично - посмотреть, какие сервисы могут полететь и оценить риски
> 
> В рамках именно этой задачи я принудительно поставить правильное время сразу. Такая роль-костыль (потому что по идее время надо выравнивать также на этапе настойки ОС, без ансибл).
> 
> 3. Еще получается, что `makestep` будет выполняться в любом случае (т.к. это не модуль, а команда). По идее можно сделать проверку "выполнять только в таких-то случаях). Возможно, это будет уместно в проде (если вообще в проде уместно добавлять такую настройку времени через роль). И тогда можно оценить, при каких условиях принудительно синхронизировать время. Но сейчас так не делаю - в моем случае выполнять обязательно надо, иначе дальше ничего не поставится
> 
> 4. Для проверки, что все ок до,бавила мини-отладку - падение, если не синхронизировано и сообщения в случае успеха и провала
> 
> 5. Изначально роль была для альмалинукс, потом выяснилось, что на дебиан у меня тоже время отлетело, добавила

 
#### 2.2.6.2. Тест роли common
 
Запускаю плейбук:
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass -v --tags common
```
 
Сработало!
 
![alt text](image-168.png)
 
### 2.2.7. Роль для установки докера
#### 2.2.7.1. Создаю роль для докера
```bash
nano roles/docker/tasks/main.yml
```
 
После
```yml
---
# tasks file for roles/docker
```
 
Вставляю:
```yml
# Установка Docker и КО на ОС на базе RedHat
- name: Установка Docker на ОС на базе RedHat
  when: ansible_os_family == "RedHat"
  block:
    - name: Добавление репозитория Docker CE (через yum_repository)
      yum_repository:
        name: docker-ce
        description: Docker CE Stable - $basearch
        baseurl: https://download.docker.com/linux/centos/8/$basearch/stable
        gpgcheck: yes
        enabled: yes
        gpgkey: https://download.docker.com/linux/centos/gpg

    - name: Установка docker-пакетов
      dnf:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-buildx-plugin
          - docker-compose-plugin
        state: present

# Установка Docker на ОС на базе Debian 
- name: Установка Docker на Debian через apt
  apt:
    name: docker.io
    state: present
    update_cache: true
  when: ansible_os_family == "Debian"

# Запуск docker и добавление в автозагрузку
- name: Запуск docker и добавление в автозагрузку
  service:
    name: docker
    enabled: true
    state: started

# Добавление пользователя в группу docker
- name: Создание группы docker
  group:
    name: docker
    state: present

- name: Добавление пользователя в группу docker
  user:
    name: "{{ ansible_user }}"
    groups: [docker]
    append: yes

# Переподключение для обновления SSH-сессии (замена newgrp docker)
- name: Перезагрузка машины
  reboot:
    reboot_timeout: 300

# Проверка docker через hello-world
- name: Проверка docker через hello-world
  command: docker run --rm hello-world
  register: docker_hello_output
  changed_when: false
  ignore_errors: true

- name: Вывод результата STDOUT hello-world
  debug:
    var: docker_hello_output.stdout_lines

- name: Вывод результата STDERR hello-world
  debug:
    var: docker_hello_output.stderr_lines
  when: docker_hello_output.rc != 0

- name: Остановка плейбука, если docker не работает
  fail:
    msg: "Падаем, докер не работает. Выше логи."
  when: docker_hello_output.rc != 0

- name: Настройка использования локального регистри по http
  when: inventory_hostname == "gitlab-runner"
  template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
    owner: root
    group: root
    mode: '0644'
  when: 
     
- name: Перезапуск docker
  when: inventory_hostname == "gitlab-runner"
  service:
    name: docker
    state: restarted
```
 
Создаю шаблон:
```bash
nano roles/docker/templates/daemon.json.j2
```
 
Вставляю:
```json
{
  "insecure-registries": ["{{ hostvars[inventory_hostname]['ansible_fqdn'] }}:5000"]
}
```
 
> Что было интересного тут:
> * Обновление групп пользователя. И вот почему:
>    * `newgrp docker` не подходит, т.к. в ансибл команда сработает только в рамках одной задачи: запускается новая шелл-сессия, применяется группа и сразу все завершается, т.е. на следующие задачи это не повлияет
>    * Узнала про `meta: reset_connection`. Думала, что поможет, т.к. она закрывает и устанавливает новое SSH-соединение. Но оказалось, что не поможет. Т.к. это не полноценный разлогин/логин: пользователь тот же, логин-сессия не пересоздаётся. Т.е. полезно, если нужно обновить окружение, но для обновления групп пользователя не подходит.
>    * Узнала, что в ансибл есть полноценный аналог "выйти и зайти нормально". `reboot` перезагружает сервер, ждёт, пока тот поднимется, и переподключается сам. Я думала, что запросит пароль для судо, но оказалось, что все ок: ансиблу достаточно того, что он уже получил пароль один раз, а дальше он просто использует его. 
> 
>         Думаю, что при настройке сервера с нуля, как сейчас в задаче - так можно делать спокойно. А если это уже работающий сервер с другими сервисами, то так не надо. В целом, можно продолжать работать с докером через `sudo` - ничего от этого не случится плохого. Если по какой-то причине нужно работать от определнного пользователя и без судо, то:
>        * лучше перезагрузить сервер руками
>        * там, где я добавляю в группу `ansible_user` есть смысл прописать свою переменную с именем нужного пользователя, если это не тот же, от лица которого мы подключаемся
> 
>         ps. хотя все равно думаю, что это избыточно, и можно работать из под текущего юзера с судо.
> 
> * Попыталась добавить отладку для проверки работоспособности докера. Как я поняла, `hello word` дает наибольшее представление о его статусе, поэтому оставила ее, как предлагают в доке, и ориентировалась на ее вывод
> * В задаче по проверке докера через `hello-world` поставила `ignore_errors: true` не чтобы игнорировать ошибки, а как раз для отладки, чтобы можно было понять, что пошло не так с полноценным выводом
> * Изначально роль была другая (первая версия роли ниже, в приложении):
>     * Для Альмы использовала добавляла репозиторий докера через command. Увидела предупрждение от докера - `[WARNING]: Consider using the dnf module rather than running 'dnf'.  If you need to use command because dnf is insufficient you can add 'warn: false' to this command task or set 'command_warnings=False' in ansible.cfg to get rid of this message.` -, изменила на добавление репозитория с помощью `yum_repository`
>     * Для Дебиан сперва устанавливала докер аналогично его оф. инструкции. После комментария Юры сменила на установку из apt, чтобы уменьшить количество шагов. На Альмалинукс не стала ставить через yum/dnf, так как команда установки докера ставит подман
> * Добавила разрешение раннеру обращаться к докер регистри по http
> 
 
 <details>
<summary><strong>Приложение: установка докер по оф. инструкции (сложнее)</strong></summary>
Сама роль: 

```yml
# Установка Docker на ОС на базе RedHat
- name: Установка Docker на ОС на базе RedHat
  when: ansible_os_family == "RedHat"
  block:
    - name: Установка dnf-плагина
      yum:
        name: dnf-plugins-core
        state: present

    - name: Добавление репозитория docker
      command:
        cmd: dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        creates: /etc/yum.repos.d/docker-ce.repo

    - name: Установка docker-пакетов
      yum:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-buildx-plugin
          - docker-compose-plugin
        state: present

# Установка Docker на ОС на базе Debian 
- name: Установка Docker на ОС на базе Debian
  when: ansible_os_family == "Debian"
  block:
    - name: Установка зависимостей
      apt:
        name:
          - ca-certificates
          - curl
        state: present
        update_cache: true

    - name: Создание директории для ключей
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Скачивание GPG ключа docker
      get_url:
        url: https://download.docker.com/linux/debian/gpg
        dest: /etc/apt/keyrings/docker.asc
        mode: '0644'

    - name: Добавление репозитория docker вручную
      block:
        - name: Формируем строку репозитория docker
          set_fact:
            docker_repo_entry: >-
              deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc]
              https://download.docker.com/linux/debian
              {{ ansible_lsb.codename }} stable

        - name: Вставка репозитория в docker.list
          lineinfile:
            path: /etc/apt/sources.list.d/docker.list
            line: "{{ docker_repo_entry }}"
            create: yes

    - name: Обновление кэша репозиториев
      apt:
        update_cache: yes

    - name: Установка docker-пакетов
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-buildx-plugin
          - docker-compose-plugin
        state: present

# Запуск docker и добавление в автозагрузку
- name: Запуск docker и добавление в автозагрузку
  service:
    name: docker
    enabled: true
    state: started

# Добавление пользователя в группу docker
- name: Создание группы docker
  group:
    name: docker
    state: present

- name: Добавление пользователя в группу docker
  user:
    name: "{{ ansible_user }}"
    groups: [docker]
    append: yes

# Переподключение для обновления SSH-сессии (замена newgrp docker)
- name: Перезагрузка машины
  reboot:
    reboot_timeout: 300

# Проверка docker через hello-world
- name: Проверка docker через hello-world
  command: docker run --rm hello-world
  register: docker_hello_output
  changed_when: false
  ignore_errors: true

- name: Вывод результата STDOUT hello-world
  debug:
    var: docker_hello_output.stdout_lines

- name: Вывод результата STDERR hello-world
  debug:
    var: docker_hello_output.stderr_lines
  when: docker_hello_output.rc != 0

- name: Остановка плейбука, если docker не работает
  fail:
    msg: "Падаем, докер не работает. Выше логи."
  when: docker_hello_output.rc != 0
```
</details>
 
 
#### 2.2.7.2. Тестирую роль для докера
 
Запускаю плейбук:
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass -v --tags docker
```
 
Тесты пройдены:
 
![alt text](image-169.png)

### 2.2.8. Роль для установки гитлаб-сервера
#### 2.2.8.1. Установка модуля докер для ансибл
Нашла такой, устанавливаю:
```bash
ansible-galaxy collection install community.docker
```
 
#### 2.2.8.2. Создаю роль для gitlab_server
```bash
nano roles/gitlab_server/tasks/main.yml
```
 
После
```yml
---
# tasks file for roles/gitlab_server
```

Вставляю
```yml
- name: Создание директории для данных gitlab server
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - "{{ gitlab_base_dir }}"
    - "{{ gitlab_config_dir }}"
    - "{{ gitlab_logs_dir }}"
    - "{{ gitlab_data_dir }}"
    - "{{ gitlab_backups_dir }}"

- name: Копирование docker-compose.yml 
  template:
    src: docker-compose.yml.j2
    dest: "{{ gitlab_base_dir }}/docker-compose.yml"
    mode: '0644'

- name: Запуск gitlab server через docker compose
  community.docker.docker_compose_v2:
    project_src: "{{ gitlab_base_dir }}"
    state: present
  register: compose_result

- name: Дебаг - вывод результата запуска gitlab server
  debug:
    msg: >-
      {% if compose_result.changed %}
      Были изменения: контейнер gitlab server запустился.
      {% else %}
      Без изменений: контейнер gitlab server уже был.
      {% endif %}

- name: Проверка доступности gitlab server по HTTP
  uri:
    url: "{{ gitlab_external_url }}"
    status_code: 200
  register: gitlab_check
  retries: 20
  delay: 30
  until: gitlab_check.status == 200

- name: Дебаг - вывод результата проверки gitlab server по HTTP
  debug:
    msg: >-
      {% if gitlab_check.status == 200 %}
      Gitlab server доступен по адресу {{ gitlab_external_url }}.
      {% else %}
      Gitlab server недоступен по адресу {{ gitlab_external_url }}: {{ gitlab_check.status }}
      {% endif %}
```
* Изначально давала меньше времени для задачи проверки по hhtp, но на моих ВМ долго стартует
 
Определяю переменные для роли:
```bash
nano roles/gitlab_server/defaults/main.yml
```
 
После:
```yml
---
# defaults file for roles/gitlab_server
```
 
Вставляю:
```yml
gitlab_version: "17.9.3-ce.0"

gitlab_hostname: "gitlab-server.lan"
gitlab_external_url: "http://gitlab-server.lan"

gitlab_ssh_port: 2222
gitlab_http_port: 80
gitlab_https_port: 443

gitlab_root_password: "verYstr0nGOcheNNN"

gitlab_base_dir: "/srv/gitlab"
gitlab_config_dir: "{{ gitlab_base_dir }}/config"
gitlab_logs_dir: "{{ gitlab_base_dir }}/logs"
gitlab_data_dir: "{{ gitlab_base_dir }}/data"
gitlab_backups_dir: "{{ gitlab_data_dir }}/backups"
```

Создаю шаблон
```bash
nano roles/gitlab_server/templates/docker-compose.yml.j2
```
 
Вставляю:
```yml
version: '3.6'

services:
  gitlab:
    image: gitlab/gitlab-ce:{{ gitlab_version }}
    container_name: gitlab
    restart: always
    hostname: '{{ gitlab_hostname }}'
    environment:
      GITLAB_ROOT_PASSWORD: "{{ gitlab_root_password }}"
      GITLAB_OMNIBUS_CONFIG: |
        external_url '{{ gitlab_external_url }}'
        gitlab_rails['gitlab_shell_ssh_port'] = {{ gitlab_ssh_port }}
    ports:
      - '{{ gitlab_http_port }}:80'
      - '{{ gitlab_https_port }}:443'
      - '{{ gitlab_ssh_port }}:22'
    volumes:
      - '{{ gitlab_config_dir }}:/etc/gitlab'
      - '{{ gitlab_logs_dir }}:/var/log/gitlab'
      - '{{ gitlab_data_dir }}:/var/opt/gitlab'
      - '{{ gitlab_backups_dir }}:/var/opt/gitlab/backups
    shm_size: '256m'
```

#### 2.2.8.3. Тестирую роль для gitlab_server
 
Запускаю плейбук:
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass -v --tags gitlab_server
```
 
Тесты пройдены:
![alt text](image-170.png)
 
### 2.2.9. Захожу в гитлаб-сервер, получаю токен для будущего раннера
> Выглядит пока так, что это нужно будет делать вручную.
 
В ручном способе я получала пароль администратора вручную. Сейчас задала его при поднятии.
 
Захожу в GitLab под пользователем root, ввожу пароль.

Я в здании:
![alt text](image-171.png) 
Снова уведомлялка, что любой пользователь может зарегистрироваться самостоятельно. Так как мой GitLab — локальный и приватный, открытая регистрация не нужна. Жмакаю `Deactivate`, чтобы отключить создание аккаунтов для всех, кроме администратора.
 
Как и при ручной установке:
- Создаю первый проект:
![alt text](image-172.png)
 
- Проверяю, что SSH-URL проекта с портом 2222, а не 22:
![alt text](image-173.png)
 
> Вижу уведомелние:
> ![alt text](image-174.png)
> Сразу с ним разберемся. Допустим, пушать буду с всл. Кликаю по синей кнопке и вставляю вывод `cat ~/.ssh/id_rsa.pub` с всл 
 
Получаю токен для **Instance Runner** (чтобы он был доступен для всех проектов в GitLab и не был привязан к какому-то конкретному репозиторию).
 
1. Перехожу в интерфейс гитлаба: http://gitlab-server.lan/admin/runners
2. Settings → CI/CD → Runners
3. Жму `New Instance Runner`
4. Заполняю:
![alt text](image-175.png)
5. Жму кнопку Create Runner, которая раньше меня смущала своим названием
> Как я понимаю, мы в интерфейсе гитлаба создаем описание раннера, гиталб под него создает "пустой слот",  выдает нам данные для регистрации раннера, мы раннер регистрируем с помощью gitlab-runner register, зареганный раннер подключается с нужным токеном, и после подключения раннер активируется и привязывается к этому слоту
6. Беру токен и несу в переменные - `glrt-t1_1txE2igLA_mE452T_EnJ`
![alt text](image-176.png)
 
### 2.2.10. Роль для установки гитлаб-раннера
#### 2.2.10.1. Создаю роль
```bash
nano roles/gitlab_runner/tasks/main.yml
```
 
После
```yml
---
# tasks file for roles/gitlab_runner
```
 
Вставляю
```yml
- name: Создание каталога под докер вольюм для хранения конфигов
  file:
    path: "{{ gitlab_runner_config_path }}"
    state: directory
    owner: root
    group: root
    mode: "0755"
    recurse: yes

- name: Запуск контейнера gitlab-runner
  community.docker.docker_container:
    name: gitlab-runner
    image: gitlab/gitlab-runner:latest
    restart_policy: always
    state: started
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - "{{ gitlab_runner_config_path }}:/etc/gitlab-runner"
    etc_hosts:
      gitlab-server.lan: "{{ hostvars['gitlab-server']['ansible_host'] }}"

- name: Регистрация gitlab-runner
  community.docker.docker_container_exec:
    container: gitlab-runner
    command: >
      gitlab-runner register
      --non-interactive
      --url "{{ gitlab_runner_url }}"
      --registration-token "{{ gitlab_runner_token }}"
      --executor "{{ gitlab_runner_executor }}"
      --description "{{ gitlab_runner_description }}"
      --tag-list "{{ gitlab_runner_tags }}"
      --run-untagged="true"
      --locked="false"
      --docker-image "{{ gitlab_runner_image }}"

- name: Ожидание появления config.toml
  ansible.builtin.wait_for:
    path: "{{ gitlab_runner_config_path }}/config.toml"
    state: present
  timeout: 10

- name: Добавление extra_hosts в config.toml
  ansible.builtin.lineinfile:
    path: "{{ gitlab_runner_config_path }}/config.toml"
    insertafter: '\[runners.docker\]'
    line: '  extra_hosts = {{ gitlab_runner_add_host | to_json }}'
```
> * `etc_hosts` - аналог `--add-host` и добавляет строчку в `/etc/hosts` контейнера раннера, чтобы сам раннер мог зарегистрироваться на гитлаб сервере.
> * `extra_hosts` - добавляет строчку в `/etc/hosts` каждого джоб-контейнера, который запускаеи раннер. Чтобы джобы могли достучаться до гитлаб сервера по имени.
  
Определяю переменные для роли:
```bash
nano roles/gitlab_runner/defaults/main.yml
```
 
После:
```yml
---
# defaults file for roles/gitlab_runner
```
 
Вставляю:
```yml
gitlab_runner_config_path: "/srv/gitlab-runner/config"
gitlab_runner_token: "glrt-t1_1txE2igLA_mE452T_EnJ"  # надо менять
gitlab_runner_url: "http://gitlab-server.lan"
gitlab_runner_description: "docker-runner"
gitlab_runner_tags: "docker"
gitlab_runner_executor: "docker"
gitlab_runner_image: "alpine:latest"
gitlab_runner_add_host:
  - "gitlab-server.lan:{{ hostvars['gitlab-server']['ansible_host'] }}"
```
> * При первом прохождении делала докер вольюм (`sudo docker volume create gitlab-runner-config`). Юра писал, что с каталогами проще, а /srv/gitlab-runner/config было в примерах в доке, поэтому взяла такую директорию
> * Про `{{ hostvars['gitlab-server']['ansible_host'] }}` - вроде удобно, если только 3 контейнера развернуть. Но если масштабировать, наверное, удобнее прописать вручную адрес. Пока так оставила
 
#### 2.2.10.2. Тестирую роль для gitlab_runner
 
Запускаю плейбук:
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass -v --tags gitlab_runner
```
 
По тестам все ок:
![alt text](image-181.png)
 
#### 2.2.10.3. Вручную проверяю работу на тестовом пайплайне
 
Работаю с всл, с нее же проверяю подключение:
```bash
 ssh -T -p 2222 git@gitlab-server.lan
```
> * -p 2222 - потому что ранее пробрасывали его вместо 22
 
Как обычно, если не просят пароль, значит все хорошо:
![alt text](image-178.png)
  
Клонирую проект по SSH
```bash
cd /home/kaya/repos/from_local_gitlab
git clone ssh://git@gitlab-server.lan:2222/root/test-project-1.git
```
> Тут погуглила, что SSH-ссылки бывают в короткой и длинной форме.
> По умолчанию - короткая.
> Длинная используется, когда у нас нестандартный порт или нужен URI-формат.
  
Проверяю, что у меня нужные настройки гита:
```bash
git config --list
```
  
Создаю тестовый ci-cd:
```bash
cd test-project-1
```
  
```bash
nano .gitlab-ci.yml
```
 
Вставляю (обязательно с тегом докер, т.к. раннер создавала с тегом):
```bash
stages:
  - test

echo_ok_job:
  stage: test
  tags:
    - docker
  script:
    - echo "ok"
```
 
Проверяю название ветки:
```bash
git branch
```
Никакое, потому что при создании репозитория я сняла галочку с создания ридми, и репозиторий оказался пустой:
 
![alt text](image-179.png)
 
Создаю ветку, сохраняю изменения и делаю пуш:
```bash
git checkout -b main
git add .
git commit -m "add test .gitlab-ci.yml"
git push -u origin main
```
 
Проверяю в UI гитлаба, что все в порядке:
Project → Build → Pipelines:
![alt text](image-70.png)
> Первый не появлялся минуту-две, и я запустила второй (без указания тега докер). Когда зашла првоерить, поняла, что все просто тормозит, но работает
![alt text](image-180.png)
 
### 2.2.11. Роль для установки docker_registry
#### 2.2.11.1. Создаю роль
```bash
nano roles/docker_registry/tasks/main.yml
```
 
После
```yml
---
# tasks file for roles/docker_registry
```
 
Вставляю
```yml
- name: Подготовка к установке docker registry
  when: inventory_hostname == "docker-registry"
  block:
  - name: Установка pip на редхат
    dnf:
      name: python3-pip
      state: present
    when: ansible_os_family == "RedHat"

  - name: Установка библиотек docker и requests
    pip:
      name:
        - docker
        - requests

- name: Установка docker registry
  when: inventory_hostname == "docker-registry"
  block:
  - name: Создание каталога под докер вольюм
    file:
      path: "{{ registry_data_dir }}"
      state: directory
      owner: root
      group: root
      mode: "0755"
      recurse: yes

  - name: Запуск контейнера registry
    community.docker.docker_container:
      name: registry
      image: registry:2
      restart_policy: always
      state: started
      volumes:
        - "{{ registry_data_dir }}:/var/lib/registry"
      ports:
        - 5000:5000

  - name: Открываю порт 5000 в редхат
    firewalld:
      port: 5000/tcp
      permanent: yes
      state: enabled
      immediate: yes
    when: ansible_os_family == "RedHat"

- name: Проверка доступности docker registry
  when: inventory_hostname == "gitlab-runner"
  block:
    - name: Проверка сервера с гитлаб-раннер
      uri:
        url: "http://{{ hostvars['docker-registry']['ansible_host'] }}:5000/v2/_catalog"
        status_code: 200
        return_content: yes
      register: registry_check
      retries: 5
      delay: 3
      until: registry_check.status == 200

    - name: Вывод ответа
      debug:
        var: registry_check.content
```
 
  
Определяю переменные для роли:
```bash
nano roles/docker_registry/defaults/main.yml
```
 
После:
```yml
---
# defaults file for roles/docker_registry
```
 
Вставляю:
```yml
registry_data_dir: "/srv/registry/data"
docker_data_dir: "/etc/docker"
```
> *  После этой роли сменила в основном плейбуке hosts с docker-registry на all, ччобы была внешняя проверка подключения
 
#### 2.2.10.2. Тестирую роль для docker_registry
 
Запускаю плейбук:
```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass -v --tags docker_registry
```
 
По тестам все ок:
![alt text](image-192.png)
 
