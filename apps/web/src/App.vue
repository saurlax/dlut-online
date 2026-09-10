<script setup lang="ts">
import {
  NButton,
  NCard,
  NConfigProvider,
  NGlobalStyle,
  NStatistic,
  NTag,
  zhCN,
  type GlobalThemeOverrides,
} from "naive-ui";
import { computed, onMounted, onUnmounted, ref } from "vue";
import { campuses, isLive, parseOnline, type Online } from "./online";
import mainBuilding from "./assets/main-building.jpg";

const themeOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: "#0041b7",
    primaryColorHover: "#245cce",
    primaryColorPressed: "#00338f",
    primaryColorSuppl: "#0041b7",
    successColor: "#32745f",
    borderRadius: "2px",
    bodyColor: "#f6f5f1",
    textColorBase: "#192b40",
    textColor2: "#5c6877",
    borderColor: "#d6dade",
    fontFamily: '"PingFang SC", "Microsoft YaHei", sans-serif',
  },
  Button: { heightLarge: "56px", fontSizeLarge: "15px", fontWeight: "500" },
  Card: { color: "transparent", paddingMedium: "24px 32px" },
  Statistic: { labelFontSize: "12px", valueFontSize: "36px", valueTextColor: "#192b40" },
  Tag: { borderRadius: "2px" },
};

const data = ref<Online | null>(null);
const failed = ref(false);
const loading = ref(true);
const now = ref(Date.now());
const live = computed(() => isLive(data.value, failed.value, now.value));
const status = computed(() =>
  loading.value ? "正在获取状态" : live.value ? "游戏服在线" : "状态未知",
);
const explanation = computed(() =>
  loading.value
    ? "正在获取校园在线情况。"
    : failed.value
      ? "暂时无法获取在线情况，稍后自动重试。"
      : live.value
        ? "当前在线人数，每 10 秒自动更新。"
        : data.value?.received_at
          ? "游戏服数据已过期，等待新的状态上报。"
          : "尚未收到游戏服状态，稍后自动更新。",
);
const updated = computed(() =>
  data.value?.received_at
    ? new Date(data.value.received_at).toLocaleString("zh-CN", {
        hour12: false,
      })
    : "暂无更新",
);
let refreshTimer: ReturnType<typeof setTimeout> | undefined;
let clockTimer: ReturnType<typeof setInterval> | undefined;
let controller: AbortController | undefined;
let disposed = false;

async function refresh() {
  controller = new AbortController();
  const timeout = setTimeout(() => controller?.abort(), 5000);
  try {
    const response = await fetch("/api/v1/game/online", {
      signal: controller.signal,
      cache: "no-store",
    });
    if (!response.ok) throw new Error("Online request failed");
    const next = parseOnline(await response.json());
    if (disposed) return;
    data.value = next;
    failed.value = false;
  } catch {
    if (!disposed) failed.value = true;
  } finally {
    clearTimeout(timeout);
    if (!disposed) {
      loading.value = false;
      now.value = Date.now();
      refreshTimer = setTimeout(refresh, 10000);
    }
  }
}
onMounted(() => {
  void refresh();
  clockTimer = setInterval(() => {
    now.value = Date.now();
  }, 1000);
});
onUnmounted(() => {
  disposed = true;
  controller?.abort();
  clearTimeout(refreshTimer);
  clearInterval(clockTimer);
});
</script>

<template>
  <n-config-provider :locale="zhCN" :theme-overrides="themeOverrides">
    <n-global-style />
    <div class="site-shell">
      <header class="site-header">
        <a class="brand" href="/" aria-label="DLUT Online 首页">
          <span class="brand-mark" aria-hidden="true">D<span>O</span></span>
          <span>DLUT <span class="brand-light">Online</span></span>
        </a>
        <nav aria-label="主导航">
          <a class="nav-link" href="#online">此刻校园</a>
          <n-button text tag="a" class="header-link" href="https://github.com/saurlax/dlut-online">
            GitHub <span class="external" aria-hidden="true">↗</span>
          </n-button>
        </nav>
      </header>
      <main>
        <section class="hero" aria-labelledby="intro-title">
          <div class="hero-copy">
            <p class="eyebrow"><span class="eyebrow-line" /> 大连理工大学主题校园世界</p>
            <h1 id="intro-title">重返校园，<br /><span>相逢此刻。</span></h1>
            <p class="intro-copy">那些走过的路，还想再走一遍。<br />以第一人称走进大工，与在线的同伴相遇。</p>
            <n-button tag="a" type="primary" size="large" class="download" href="https://github.com/saurlax/dlut-online/releases">
              下载客户端 <span aria-hidden="true">↗</span>
            </n-button>
            <p class="platforms">Windows x86_64 <span>/</span> macOS universal</p>
          </div>
          <figure class="hero-visual">
            <div class="photo-frame">
              <img :src="mainBuilding" alt="阳光下的大连理工大学主楼，石材立面与门廊" width="1280" height="960" fetchpriority="high" />
              <span class="photo-wordmark" aria-hidden="true">DLUT</span>
            </div>
            <figcaption><span>主楼 / 校园实景</span><span aria-hidden="true">DALIAN UNIVERSITY OF TECHNOLOGY</span></figcaption>
          </figure>
          <div class="hero-bottom" aria-hidden="true"><span>熟悉的风景，新的相遇</span><span>向下探索 ↓</span></div>
        </section>
        <section id="online" class="online-section" aria-labelledby="online-title">
          <div class="section-heading">
            <div class="section-title"><span class="section-index" aria-hidden="true">01 /</span><h2 id="online-title">此刻，校园里</h2></div>
            <n-tag size="small" :bordered="false" :type="live ? 'success' : 'default'" class="status" role="status">
              <span class="status-dot" :class="{ 'is-live': live }" />{{ status }}
            </n-tag>
          </div>
          <div class="campus-grid">
            <n-card :bordered="false" class="campus-card total-card">
              <div class="campus-top"><h3>总在线人数</h3><span aria-hidden="true">↗</span></div>
              <n-statistic :value="live ? (data?.total ?? 0) : '—'">
                <template v-if="live" #suffix><span class="count-unit">人</span></template>
              </n-statistic>
              <span class="campus-caption">此刻同行</span>
            </n-card>
            <n-card v-for="campus in campuses" :key="campus.id" :bordered="false" class="campus-card">
              <div class="campus-top"><h3>{{ campus.name }}</h3><span class="campus-number">{{ campus.number }}</span></div>
              <n-statistic :value="live ? (data?.campuses?.[campus.id] ?? 0) : '—'">
                <template v-if="live" #suffix><span class="count-unit">人</span></template>
              </n-statistic>
              <span class="campus-caption">{{ live ? '当前在线' : '等待更新' }}</span>
            </n-card>
          </div>
          <div class="status-copy"><p>{{ explanation }}</p><p>最后上报：{{ updated }}</p></div>
        </section>
      </main>
      <footer><span class="footer-brand">DLUT Online</span><span>校园探索，从这里开始。</span><a href="https://github.com/saurlax/dlut-online">开源校园世界 <span aria-hidden="true">↗</span></a></footer>
    </div>
  </n-config-provider>
</template>
