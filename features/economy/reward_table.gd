extends Resource
class_name RewardTable

@export var coin_reward_min: int = 5
@export var coin_reward_max: int = 12
@export var business_xp_reward: int = 1

func roll_coins(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(coin_reward_min, coin_reward_max)
