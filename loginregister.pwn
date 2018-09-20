#include <a_samp>
#include <a_mysql>
#include <easyDialog>

#define MYSQL_HOSTNAME		"localhost" // Change this to your own MySQL hostname
#define MYSQL_USERNAME		"root" // As above 
#define MYSQL_PASSWORD		"" // Change this if you're using a password for your MySQL setup, I'm not using any so I'll leave it blank.
#define MYSQL_DATABASE		"willbedie" // Change this to your own MySQL Database 

new
	MySQL: Database, // This is the handle.
	PlayerName[MAX_PLAYERS][30], // We will use this to store player's name
	PlayerIP[MAX_PLAYERS][17]	// We will use this to store a player's IP Address
;

native WP_Hash(buffer[], len, const str[]); //This is a Whirlpool function, we will need that to store the passwords.

enum PlayerData // We'll create a new enum to store player's information(data)
{
	ID,
	Password[129],
	Cash,
	Kills,
	Deaths
};
new PlayerInfo[MAX_PLAYERS][PlayerData];

public OnGameModeInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true); // it automatically reconnects when loosing connection to mysql server

	Database = mysql_connect(MYSQL_HOSTNAME, MYSQL_USERNAME, MYSQL_PASSWORD, MYSQL_DATABASE, option_id); // AUTO_RECONNECT is enabled for this connection handle only
	if (Database == MYSQL_INVALID_HANDLE || mysql_errno(Database) != 0)
	{
		print("MySQL connection failed. Server is shutting down."); // Read below
		SendRconCommand("exit"); // close the server if there is no connection
		return 1;
	}

	SetGameModeText("SERVER VERSION");
	print("MySQL connection is successful."); // If the MySQL connection was successful, we'll print a debug!
	return 1;
}

public OnPlayerConnect(playerid)
{
	new query[140];
	GetPlayerName(playerid, PlayerName[playerid], 30); // This will get the player's name 
	GetPlayerIp(playerid, PlayerIP[playerid], 16); // This will get the player's IP Address

	mysql_format(Database, query, sizeof(query), "SELECT `Password`, `ID` FROM `users` WHERE `Username` = '%e' LIMIT 0, 1", PlayerName[playerid]); // We are selecting the password and the ID from the player's name
	mysql_tquery(Database, query, "CheckPlayer", "i", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SavePlayer(playerid);
}

Dialog:DIALOG_LOGIN(playerid, response, listitem, inputtext[])
{
	if(!response) 
		return Kick(playerid); // If the player has pressed exit, kick them.

	new password[129], query[100];
	WP_Hash(password, 129, inputtext); // We're going to hash the password the player has written in the login dialog
	if(!strcmp(password, PlayerInfo[playerid][Password])) // This will check if the password we used to register with matches
	{ // If it matches
		mysql_format(Database, query, sizeof(query), "SELECT * FROM `users` WHERE `Username` = '%e' LIMIT 0, 1", PlayerName[playerid]);
		mysql_tquery(Database, query, "LoadPlayer", "i", playerid); //Let's call LoadPlayer.
	}
	else // If the password doesn't match.
	{
		Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "{FF0000}Wrong Password!\n{FFFFFF}Type your correct password below to continue and sign in to your account", "Login", "Exit");
		// We will show this dialog to the player and tell them they have wrote an incorrect password.
	}
	return 1;
}

Dialog:DIALOG_REGISTER(playerid, response, listitem, inputtext[])
{
	if(!response)
		return Kick(playerid);

	if(strlen(inputtext) < 3) return Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", "{FF0000}Short Password!\n{FFFFFF}Type a 3+ characters password if you want to register and play on this server", "Register", "Exit");
	//If the password is less than 3 characters, show them a dialog telling them to input a 3+ characters password
	new query[300];
	WP_Hash(PlayerInfo[playerid][Password], 129, inputtext); // Hash the password the player has wrote to the register dialog using Whirlpool.
	mysql_format(Database, query, sizeof(query), "INSERT INTO `users` (`Username`, `Password`, `IP`, `Cash`, `Kills`, `Deaths`) VALUES ('%e', '%e', '%e', 0, 0, 0)", PlayerName[playerid], PlayerInfo[playerid][Password], PlayerIP[playerid]);
	// Insert player's information into the MySQL database so we can load it later.
	mysql_tquery(Database, query, "RegisterPlayer", "i", playerid); // We'll call this as soon as the player successfully registers.
	return 1;
}

forward CheckPlayer(playerid);
public CheckPlayer(playerid)
{
	new rows, string[150];
	cache_get_row_count(rows);

	if(rows) // If row exists 
	{
		cache_get_value_name(0, "Password", PlayerInfo[playerid][Password], 129); // Load the player's password
		cache_get_value_name_int(0, "ID", PlayerInfo[playerid][ID]); // Load the player's ID.
		format(string, sizeof(string), "Welcome back to the server.\nPlease type your password below to login to your account."); // A dialog will pop up telling the player to write they password below to login.
		Dialog_Show(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Exit");
	}
	else // If there are no rows, we need to show the register dialog!
	{	
		format(string, sizeof(string), "Welcome to our server.\nIf you want to play here, you must register an account. Type a strong password below to register."); // A dialog with this note will pop up telling the player to register his acocunt.
		Dialog_Show(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", string, "Register", "Exit");
	}
	return 1;
}

forward LoadPlayer(playerid);
public LoadPlayer(playerid)
{
	cache_get_value_name_int(0, "Cash", PlayerInfo[playerid][Cash]);
	cache_get_value_name_int(0, "Kills", PlayerInfo[playerid][Kills]);
	cache_get_value_name_int(0, "Deaths", PlayerInfo[playerid][Deaths]);

	GivePlayerMoney(playerid, PlayerInfo[playerid][Cash]); //Load the player's cash and give it to them.
	return 1;
}

forward SavePlayer(playerid);
public SavePlayer(playerid)
{
	new query[140];
	mysql_format(Database, query, sizeof(query), "UPDATE `users` SET `Cash` = '%d', `Kills` = '%d', `Deaths` = '%d' WHERE `ID` = '%d'", PlayerInfo[playerid][Cash], PlayerInfo[playerid][Kills], PlayerInfo[playerid][Deaths], PlayerInfo[playerid][ID]);
	// We will format the query to save the player and we will use this as soon as a player disconnects.
	mysql_tquery(Database, query); //We will execute the query.
	return 1;
}

forward RegisterPlayer(playerid);
public RegisterPlayer(playerid)
{
	PlayerInfo[playerid][ID] = cache_insert_id();
	printf("A new account with the id of %d has been registered!", PlayerInfo[playerid][ID]); // You can remove this if you want, I just used it to debug.
	return 1;
}