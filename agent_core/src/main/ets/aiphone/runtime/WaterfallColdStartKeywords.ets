/**
 * Broad cold-start queries distilled from cross-domain public trend lists.
 * Keep the domestic and global lists aligned by topic and free of transient
 * event sentences, people names, or unverified claims.
 */
export const WATERFALL_DOMESTIC_COLD_START_KEYWORDS: string[] = [
  '人工智能', '科技数码', '编程开发', '科学科普',
  '美食餐饮', '家常菜谱', '旅行攻略', '城市生活',
  '体育赛事', '足球篮球', '财经市场', '商业投资',
  '动画番剧', '漫画作品', '电子游戏', '电影电视剧',
  '国际政治', '军事国防', '地缘政治', '国际新闻',
  '大语言模型', 'AI智能体', 'DeepSeek', 'OpenAI',
  '生成式AI', '具身智能', '人形机器人', '自动驾驶',
  '新能源汽车', '芯片半导体', '商业航天', '量子计算',
  '脑机接口', '无人机', '智能家居', '网络安全',
  '开源软件', '数码新品', '手机评测', '电脑硬件',
  'A股', '黄金价格', '油价', '房价',
  '公积金', '个人理财', '就业趋势', '职场成长',
  '创业公司', '消费趋势', '电商', '直播带货',
  '内容创作', '新质生产力', '宏观经济', '全球市场',
  '法律热点', '教育改革', '考研', '留学',
  '健康养生', '减脂健身', '睡眠健康', '心理健康',
  '医疗科普', '育儿', '养老', '食品安全',
  '天气预警', '台风', '地震科普', '环境保护',
  '气候变化', '天文宇宙', '生物科技', '历史文化',
  '传统文化', '非物质文化遗产', '哲学思考', '情感关系',
  'GTA6', '黑神话', '原神', '电子竞技',
  'Steam游戏', '独立游戏', '科幻作品', '悬疑推理',
  '音乐现场', '播客', '摄影', '短视频',
  '乒乓球', '羽毛球', '跑步', '户外运动',
  '自驾游', '咖啡', '宠物', '家居装修'
];

export const WATERFALL_GLOBAL_COLD_START_KEYWORDS: string[] = [
  'artificial intelligence', 'consumer technology', 'software development', 'popular science',
  'food and restaurants', 'home cooking', 'travel guides', 'urban lifestyle',
  'sports news', 'football and basketball', 'financial markets', 'business and investing',
  'anime', 'manga', 'video games', 'movies and television',
  'world politics', 'military and defense', 'geopolitics', 'international news',
  'large language models', 'AI agents', 'DeepSeek', 'OpenAI',
  'generative AI', 'embodied AI', 'humanoid robots', 'autonomous driving',
  'electric vehicles', 'semiconductors', 'space exploration', 'quantum computing',
  'brain computer interface', 'drones', 'smart homes', 'cybersecurity',
  'open source software', 'new gadgets', 'smartphone reviews', 'PC hardware',
  'stock market', 'gold prices', 'oil prices', 'housing market',
  'mortgage rates', 'personal finance', 'job market', 'career development',
  'startups', 'consumer trends', 'ecommerce', 'livestream shopping',
  'creator economy', 'future industries', 'macroeconomics', 'global economy',
  'law and policy', 'education reform', 'graduate school', 'study abroad',
  'health and wellness', 'weight loss and fitness', 'sleep health', 'mental health',
  'medical science', 'parenting', 'healthy aging', 'food safety',
  'extreme weather', 'typhoons', 'earthquake science', 'environmental protection',
  'climate change', 'astronomy', 'biotechnology', 'world history',
  'traditional culture', 'cultural heritage', 'philosophy', 'relationships',
  'GTA 6', 'Black Myth', 'Genshin Impact', 'esports',
  'Steam games', 'indie games', 'science fiction', 'mystery stories',
  'live music', 'podcasts', 'photography', 'short videos',
  'table tennis', 'badminton', 'running', 'outdoor adventures',
  'road trips', 'coffee', 'pets', 'interior design'
];

/** One semantic cold-start topic with source-appropriate query text. */
export interface WaterfallColdStartTopic {
  id: string;
  domesticQuery: string;
  globalQuery: string;
}

function buildColdStartTopics(): WaterfallColdStartTopic[] {
  const topics: WaterfallColdStartTopic[] = [];
  const count = Math.min(
    WATERFALL_DOMESTIC_COLD_START_KEYWORDS.length,
    WATERFALL_GLOBAL_COLD_START_KEYWORDS.length
  );
  for (let index = 0; index < count; index++) {
    topics.push({
      id: 'cold-start-' + (index + 1).toString(),
      domesticQuery: WATERFALL_DOMESTIC_COLD_START_KEYWORDS[index],
      globalQuery: WATERFALL_GLOBAL_COLD_START_KEYWORDS[index]
    });
  }
  return topics;
}

/** The canonical cold-start data set: 100 concepts, not 200 independent tasks. */
export const WATERFALL_COLD_START_TOPICS: WaterfallColdStartTopic[] = buildColdStartTopics();
export const WATERFALL_COLD_START_TOPIC_COUNT: number = WATERFALL_COLD_START_TOPICS.length;

/** Kept for compatibility; now reports semantic keyword/topic count. */
export const WATERFALL_COLD_START_KEYWORD_COUNT: number = WATERFALL_COLD_START_TOPIC_COUNT;

/** Number of stored language variants across all topics. */
export const WATERFALL_COLD_START_QUERY_VARIANT_COUNT: number =
  WATERFALL_DOMESTIC_COLD_START_KEYWORDS.length + WATERFALL_GLOBAL_COLD_START_KEYWORDS.length;
