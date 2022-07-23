//Rock logic

#include "/Entities/Common/Attacks/Hitters.as";
#include "MakeDustParticle.as"

// defines amount of damage as well as maximum separate hits
// - in terms of this's health. see config
const f32 ROCK_DAMAGE = 1.0f;

u32 g_lastplayedsound = 0;

//sprite functions
void onInit(CSprite@ this)
{
	//set a random frame
	Animation@ anim = this.addAnimation("Rock", 0, false);
	anim.AddFrame(this.getBlob().getNetworkID() % 4);
	this.SetAnimation(anim);
}

//blob functions
Random _r(0xca7a);

void onInit(CBlob@ this)
{
	if (getNet().isServer())
	{
		this.server_SetTimeToDie(4 + _r.NextRanged(2));
	}

	this.getShape().getConsts().mapCollisions = false;
	this.getShape().getConsts().bullet = false;
	this.getShape().getConsts().net_threshold_multiplier = 4.0f;

}

void onTick(CBlob@ this)
{
	const f32 vellen = this.getShape().vellen;

	// chew through backwalls

	bool isServer = getNet().isServer();
	bool isClient = getNet().isClient();

	if (vellen > 2.0f)
	{
		Vec2f pos = this.getPosition();

		if (isClient && (getGameTime() + this.getNetworkID() * 31) % 7 == 0)
		{
			MakeRockDustParticle(
				pos,
				"Smoke.png",
				this.getOldVelocity() * 0.06 + Vec2f(0.0, 0.2));
		}

		CMap@ map = this.getMap();
		Tile tile = map.getTile(pos);

		if (map.isTileBackgroundNonEmpty(tile) && this.getTickSinceCreated() > 9.0f - vellen*0.42f) // prevent hitting backtiles if just created.
		{
			if (isServer)
			{
				if (map.getSectorAtPosition(pos, "no build") !is null)
				{
					return;
				}
				map.server_DestroyTile(pos, 2.0f, this);

				// slightly damage the rock too
				this.server_Hit(this, this.getPosition(), this.getVelocity(), 0.05f, Hitters::cata_stones, true);
			}
		}
		else if (map.isTileSolid(tile))
		{
			if (!isServer)
				this.getShape().SetStatic(true);
		}

		if (isServer)
		{
			Pierce(this);
		}
	}
	else
	{
		if (isServer)
			this.server_Die();
	}
}

void MakeRockDustParticle(Vec2f pos, string file, Vec2f vel=Vec2f(0.0, 0.0))
{
	CParticle@ temp = ParticleAnimated(CFileMatcher(file).getFirst(), pos, vel, 0.0f, 1.0f, 3, 0.0f, false);

	if (temp !is null)
	{
		temp.rotation = Vec2f(-1, 0);
		temp.rotation.RotateBy(_r.NextFloat() * 360.0f);
		temp.rotates = true;

		temp.width = 8;
		temp.height = 8;
	}
}

bool canHitBlob(CBlob@ this, CBlob@ blob)
{

	CBlob@ carrier = blob.getCarriedBlob();

	if (carrier !is null)
		if (carrier.hasTag("player")
		        && (this.getTeamNum() == carrier.getTeamNum() || blob.hasTag("temp blob")))
			return false;

	return (this.getTeamNum() != blob.getTeamNum() || blob.getShape().isStatic())
	       && !blob.hasTag("invincible");

}

bool CollidesWithPlatform(CBlob@ this, CBlob@ blob, Vec2f velocity)
{
	f32 platform_angle = blob.getAngleDegrees();	
	Vec2f direction = Vec2f(0.0f, -1.0f);
	direction.RotateBy(platform_angle);
	float velocity_angle = direction.AngleWith(velocity);

	return !(velocity_angle > -90.0f && velocity_angle < 90.0f);
}

float HitMap(CBlob@ this, CMap@ map, Vec2f tilepos, bool ricochet)
{
	TileType t = map.getTile(tilepos).type;

	// another rock may have hit this tile on the same tick...
	if (t == 0)
	{
		return 0.0;
	}

	if (map.isTileCastle(t) || map.isTileWood(t))
	{
		if (map.getSectorAtPosition(tilepos, "no build") is null)
		{
			// make particles
			if (isClient())
			{
				if (map.isTileWood(t))
				{
					// throw wood particles on the back of where the projectile hit
					for (int i = 0; i < 2; ++i)
					{
						makeGibParticle(
							"/GenericGibs",
							this.getPosition(),
							getRandomVelocity(this.getOldVelocity().getAngle(), XORRandom(2.0f) + 4.0f, 30.0f),
							1,
							4 + XORRandom(4),
							Vec2f(8, 8),
							2.0f,
							0,
							"",
							0
						);
					}
				}
				else
				{
					// show some stone dust particles where the catapult hit
					MakeRockDustParticle(this.getPosition() - (this.getOldVelocity() * 3.0), "Smoke.png");
				}
			}

			const float dmg = map.isTileCastle(t) ? 0.5f : 1.0f;

			map.server_DestroyTile(tilepos, dmg, this);
			return 0.4f; // ~3 hits before the rock dies
		}
	}

	if (isClient())
	{
		if (XORRandom(3) == 0)
		{
			MakeDustParticle(this.getPosition(), "/dust2");
		}
		
		u32 gametime = getGameTime();
		if (getNet().isClient() && (gametime) > g_lastplayedsound + 2)
		{
			g_lastplayedsound = gametime;
			Sound::Play("/thud", this.getPosition(), 0.2f * Maths::Min(Maths::Max(0.5f, this.getOldVelocity().Length()), 1.5f));
		}
	}

	return 0.5f;
}

void onDie(CBlob@ this)
{
	if (isClient())
	{
		// make gib particles that aren't the cata particles
		// we want to differentiate a particule from a ricochetting rock visually
		makeGibParticle(
			"rocks.png", // not CataRocks.png
			this.getPosition(),
			getRandomVelocity(-this.getOldVelocity().getAngle(), XORRandom(4.0f) + 2.0f, 10.0f),
			1,
			XORRandom(4), // any of the smaller frames
			Vec2f(8, 8),
			7.0f,
			0,
			"",
			0
		);

		u32 gametime = getGameTime();
		if (gametime > g_lastplayedsound + 2)
		{
			g_lastplayedsound = gametime;
			Sound::Play("/rock_hit", this.getPosition(), Maths::Min(Maths::Max(0.5f, this.getOldVelocity().Length()), 1.5f));
		}
	}
}

void Pierce(CBlob @this)
{
	CMap@ map = this.getMap();

	Vec2f initVelocity = this.getVelocity();

	Vec2f velDir = initVelocity;
	f32 vellen = velDir.Normalize();

	if (vellen < 0.1f)
	{
		this.server_Die();
		return;
	}

	f32 angle = velDir.Angle();

	Vec2f pos = this.getPosition();
	Vec2f oldpos = this.getShape().getVars().oldpos;

	Vec2f displacement = pos - oldpos;
	f32 displen = displacement.Length();

	HitInfo@[] hitInfos;

	u32 gametime = getGameTime();

	const float damageBudget = this.getHealth();
	float damageDealt = 0.0f;

	bool ricochet = false;
	
	if (map.getHitInfosFromArc(oldpos, -angle, 0, displen, this, true, @hitInfos))
	{
		for (uint i = 0; i < hitInfos.length; i++)
		{
			HitInfo@ hi = hitInfos[i];

			if (hi.blob !is null) // blob
			{
				if (hi.blob.getShape().getConsts().platform && !CollidesWithPlatform(this, hi.blob, this.getVelocity()))
				return;

				if (canHitBlob(this, hi.blob))
				{
					const float oldTargetHealth = hi.blob.getHealth();
					this.server_Hit(hi.blob, hi.hitpos, initVelocity, Maths::Min(ROCK_DAMAGE, damageBudget), Hitters::cata_stones, true);
					const float newTargetHealth = hi.blob.getHealth();

					if (newTargetHealth < oldTargetHealth)
					{
						damageDealt += (oldTargetHealth - newTargetHealth);
					}
				}
			}
			else //map
			{
				Vec2f tilepos = hi.hitpos + velDir;

				damageDealt += HitMap(this, map, tilepos, true);
				
				// bounce only if we didn't fully break the block 
				ricochet = map.getTile(tilepos).type != 0;

				if (ricochet)
				{
					this.setPosition(this.getOldPosition());
				}

				if (damageDealt > 0.0f)
				{
					this.setPosition(hi.hitpos - velDir * 0.4f);
				}
			}

			if (damageDealt > 0.0f)
			{
				break;
			}
		}
	}

	if (damageDealt > 0.0f)
	{
		if (getNet().isServer())
		{
			uint seed = (getGameTime() * (this.getNetworkID() * 997 + 1337));
			Random@ r = Random(seed);

			this.server_Hit(this, pos, initVelocity, damageDealt, Hitters::cata_stones, true);

			if (ricochet)
			{
				this.setVelocity(Vec2f(r.NextFloat() - 0.5f, r.NextFloat() - 0.5f) * vellen * 1.5f + initVelocity * 0.25f);
			}
		}
	}
}
