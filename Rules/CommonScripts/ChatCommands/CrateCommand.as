#include "ChatCommand.as"
#include "MakeCrate.as";

class CrateCommand : ChatCommand
{
	CrateCommand()
	{
		super("crate", "Spawn a crate with an optional blob inside.");
		SetDebugOnly();
	}

	void Execute(string[] args, CPlayer@ player)
	{
		CBlob@ blob = player.getBlob();

		if (blob is null)
		{
			if (player.isMyPlayer())
			{
				client_AddToChat("Blobs cannot be spawned while dead or spectating", ConsoleColour::ERROR);
			}
			return;
		}

		Vec2f pos = blob.getPosition();
		u8 team = player.getTeamNum();

		if (args.size() == 0)
		{
			if (isServer())
			{
				server_MakeCrate("", "", 0, team, pos);
			}
			return;
		}

		string blobName = args[0];
		args.removeAt(0);

		//TODO: make description kids safe
		string description = join(args, " ");

		if (ChatCommands::isBlobBlacklisted(blobName))
		{
			if (player.isMyPlayer())
			{
				client_AddToChat("Crates cannot be spawned containing this blob", ConsoleColour::ERROR);
			}
			return;
		}

		if (isServer())
		{
			//TODO: show correct crate icon for siege
			server_MakeCrate(blobName, description, 0, team, pos);
		}
	}
}
