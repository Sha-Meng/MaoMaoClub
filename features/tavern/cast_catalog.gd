extends RefCounted
class_name CastCatalog

const CUSTOMER_IDS: Array[String] = ["customer_squirrel", "customer_dog", "customer_capybara", "customer_fox", "customer_rabbit", "customer_raccoon"]
const STAFF_IDS: Array[String] = ["manager", "bartender", "server"]
const PROFILES: Dictionary = {
	"customer_squirrel": {"name": "阿栗", "species": "汗衫松鼠", "trait": "健谈直爽", "body": "矮瘦轻巧，亮眼笑", "height": 78.0, "speed": 64.0, "sheet": 0, "row": 0, "social": 0.95, "warmup": 0.0, "gesture": "story", "quote": "今天可热闹了！", "reply": "然后呢？", "description": "喜欢分享新鲜事，也会认真听回应。没人想聊时就笑着收手。"},
	"customer_dog": {"name": "阿领", "species": "领带狗", "trait": "拘谨认真", "body": "瘦高内收，认真眉眼", "height": 104.0, "speed": 48.0, "sheet": 0, "row": 1, "social": 0.45, "warmup": 5.0, "gesture": "loosen_tie", "quote": "今天终于忙完了。", "reply": "这里真让人放松。", "description": "下班后想安静坐坐。先倾听，再慢慢放下拘谨，松开领带。"},
	"customer_capybara": {"name": "慢慢", "species": "格衫水豚", "trait": "淡定慢热", "body": "宽胖低重心，半垂眼", "height": 88.0, "speed": 36.0, "sheet": 0, "row": 2, "social": 0.35, "warmup": 3.0, "gesture": "slow_nod", "quote": "慢慢来，挺好的。", "reply": "嗯，我在听。", "description": "喜欢不被催促的片刻。转头、点头，也能算一场舒服的聊天。"},
	"customer_fox": {"name": "绯绯", "species": "围巾狐狸", "trait": "机敏爱逗趣", "body": "高挑侧站，挑眉偏笑", "height": 99.0, "speed": 56.0, "sheet": 1, "row": 0, "social": 0.8, "warmup": 1.0, "gesture": "quip", "quote": "猜猜我发现了什么？", "reply": "开个小玩笑。", "description": "爱观察，也爱逗趣。说完会看对方反应，见好就收。"},
	"customer_rabbit": {"name": "小绘", "species": "画手兔子", "trait": "害羞但好奇", "body": "窄肩长耳，圆眼好奇", "height": 92.0, "speed": 44.0, "sheet": 1, "row": 1, "social": 0.3, "warmup": 8.0, "gesture": "sketch", "quote": "我画了这里……", "reply": "你想看看吗？", "description": "先观察，再画两笔。自在之后，会把画本转给别人看。"},
	"customer_raccoon": {"name": "夜豆", "species": "连帽浣熊", "trait": "慢热冷幽默", "body": "矮壮后仰，困倦眼", "height": 80.0, "speed": 45.0, "sheet": 1, "row": 2, "social": 0.4, "warmup": 8.0, "gesture": "phone", "quote": "我只看一下时间。", "reply": "好吧，已经半小时了。", "description": "手机是社交缓冲。抬眼、收起手机后，偶尔接一句冷笑话。"},
	"manager": {"name": "店长", "species": "奶油猫", "trait": "热情有分寸", "body": "圆润松弛，自然短肢", "height": 88.0, "speed": 43.0, "sheet": 2, "row": 0, "social": 1.0, "warmup": 0.0, "gesture": "greet", "quote": "坐得还舒服吗？", "reply": "嗯，我在听。", "description": "自由走走，先招呼再倾听。你想独处时，就自然离开。"},
	"bartender": {"name": "调酒员", "species": "深灰猫", "trait": "专注讲究", "body": "瘦高挺直，细长专注眼", "height": 102.0, "speed": 48.0, "sheet": 2, "row": 1, "social": 0.2, "warmup": 0.0, "gesture": "align_glass", "quote": "这杯，刚刚好。", "reply": "马上就好。", "description": "把杯子摆正再出杯。动作利落，完成之后才露出一点满意。"},
	"server": {"name": "服务员", "species": "橘白猫", "trait": "积极细心", "body": "紧凑轻快，开朗圆眼", "height": 77.0, "speed": 70.0, "sheet": 2, "row": 2, "social": 0.7, "warmup": 0.0, "gesture": "apron", "quote": "您的饮品，请慢用！", "reply": "需要什么叫我就好。", "description": "走路轻快，放杯认真。先确认客人，再把杯子轻轻放稳。"}
}

static func profile(id: String) -> Dictionary:
	return PROFILES.get(id, PROFILES["customer_dog"])


static func is_customer(id: String) -> bool:
	return id in CUSTOMER_IDS


static func all_ids() -> Array[String]:
	var result: Array[String] = CUSTOMER_IDS.duplicate()
	result.append_array(STAFF_IDS)
	return result
