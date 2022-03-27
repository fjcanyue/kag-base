#include "ChatCommand.as"

class BotCommand : ChatCommand
{
	BotCommand()
	{
		super("bot", "Spawn a bot.");
		AddAlias("henry");
		SetModOnly();
	}

	void Execute(string[] args, CPlayer@ player)
	{
		if (isServer())
		{
			AddBot("Henry");
		}
	}
}
