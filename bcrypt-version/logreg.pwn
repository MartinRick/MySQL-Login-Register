#include <a_samp>
#include <a_mysql>
#include <bcrypt>
#include <easyDialog>

#define	BCRYPT_COST	12

#define MYSQL_HOSTNAME		"localhost" // Change this to your own MySQL hostname
#define MYSQL_USERNAME		"root" // Change this
#define MYSQL_PASSWORD		"" // If you have a password, type it there. If you don't leave it blank.
#define MYSQL_DATABASE		"willbedie" // Change this

new
	MySQL: Database,
	bool:LoggedIn[MAX_PLAYERS]
;

enum PlayerData
{
	user_id,
	user_cash,
	user_kills,
	user_deaths
};
new PlayerInfo[MAX_PLAYERS][PlayerData];

public OnGameModeInit()
{
	Database = mysql_connect(MYSQL_HOSTNAME, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE);
	if(Database == MYSQL_INVALID_HANDLE || mysql_errno(Database) != 0)
	{
		print("SERVER: MySQL Connection failed, shutting the server down!");
		SendRconCommand("exit");
		return 1;
	}

	SetGameModeText("willbedie");
	print("SERVER: MySQL Connection was successful.");
	return 1;
}

public OnPlayerConnect(playerid)
{
	new query[200];
	mysql_format(Database, query, sizeof(query), "SELECT * FROM `players` WHERE `Username` = '%e'", GetName(playerid));
	mysql_tquery(Database, query, "CheckAccount", "d", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid)
{
	new query[200];
	mysql_format(Database, query, sizeof(query), "UPDATE `players` SET `Cash` = '%i', `Kills` = '%i', `Deaths` = '%i' WHERE `ID` = '%i'", PlayerInfo[playerid][user_cash], PlayerInfo[playerid][user_kills], PlayerInfo[playerid][user_deaths], PlayerInfo[playerid][user_id]);
	mysql_query(Database, query);
	return 1;
}

forward CheckAccount(playerid);
public CheckAccount(playerid)
{
	new string[300];
	if(cache_num_rows())
	{
		format(string, sizeof(string), "{FFFFFF}Welcome back to {AFAFAF}Server{FFFFFF}%s. Please input your password below to log-in.", GetName(playerid));
		Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login to the server", string, "Login", "Dip");
	}
	else
	{
		format(string, sizeof(string), "{FFFFFF}Welcome to our server, %s. Please type a strong password below to continue.", GetName(playerid));
		Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register to the server", string, "Register", "Dip");
	}
	return 1;
}

Dialog:DIALOG_REGISTER(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		bcrypt_hash(inputtext, BCRYPT_COST, "OnPasswordHashed", "d", playerid);
	}
	else
		Kick(playerid);
	return 1;
}

Dialog:DIALOG_LOGIN(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		new query[300], Password[BCRYPT_HASH_LENGTH];
		mysql_format(Database, query, sizeof(query), "SELECT `Password` FROM `players` WHERE `Username` = '%e'", GetName(playerid));
		mysql_query(Database, query);
		cache_get_value_name(0, "Password", Password, BCRYPT_HASH_LENGTH);
		bcrypt_check(inputtext, Password, "OnPasswordChecked", "d", playerid);
	}
	else
		Kick(playerid);
	return 1;
}

forward OnPasswordHashed(playerid);
public OnPasswordHashed(playerid)
{
	new hash[BCRYPT_HASH_LENGTH], query[300];
	bcrypt_get_hash(hash);
	mysql_format(Database, query, sizeof(query), "INSERT INTO `players` (`Username`, `Password`, `IPAddress`, `Cash`, `Kills`, `Deaths`) VALUES ('%e', '%e', '%e', 0, 0, 0)", GetName(playerid), hash, ReturnIP(playerid));
	mysql_tquery(Database, query, "OnPlayerRegister", "d", playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	SpawnPlayer(playerid);
	SendClientMessage(playerid, -1, "You have been successfully registered in our server.");
	return 1;	
}

forward OnPasswordChecked(playerid);
public OnPasswordChecked(playerid)
{
	new bool:match = bcrypt_is_equal();
	if(match)
	{
		new query[300];
		mysql_format(Database, query, sizeof(query), "SELECT * FROM `players` WHERE `Username` = '%e'", GetName(playerid));
		mysql_tquery(Database, query, "OnPlayerLoad", "d", playerid);
	}
	else
	{
		new string[100];
		format(string, sizeof(string), "Wrong Password!\nPlease type your correct password below.");
		Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login to our server", string, "Register", "Dip");
	}
	return 1;
}

forward OnPlayerLoad(playerid);
public OnPlayerLoad(playerid)
{
	cache_get_value_name_int(0, "ID", PlayerInfo[playerid][user_id]);
	cache_get_value_name_int(0, "Cash", PlayerInfo[playerid][user_cash]);
	cache_get_value_name_int(0, "Kills", PlayerInfo[playerid][user_kills]);
	cache_get_value_name_int(0, "Deaths", PlayerInfo[playerid][user_deaths]);

	LoggedIn[playerid] = true;
	SendClientMessage(playerid, -1, "Welcome back to our server.");
	return 1;
}

GetName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof(name));
	return name;
}

ReturnIP(playerid)
{
	new PlayerIP[17];
	GetPlayerIp(playerid, PlayerIP, sizeof(PlayerIP));
	return PlayerIP;
}