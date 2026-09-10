<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import { campuses, isLive, parseOnline, type Online } from "./online";

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
  <div class="site-shell">
    <header class="site-header">
      <a class="brand" href="/" aria-label="DLUT Online 首页"
        ><span class="brand-mark" aria-hidden="true">D</span>DLUT Online</a
      >
      <a class="header-link" href="https://github.com/saurlax/dlut-online"
        >GitHub <span aria-hidden="true">↗</span></a
      >
    </header>
    <main>
      <section class="intro" aria-labelledby="intro-title">
        <p class="eyebrow">校园世界，正在连接</p>
        <h1 id="intro-title">在熟悉的校园，<br />遇见新的日常。</h1>
        <p class="intro-copy">
          以大连理工大学为主题的第一人称校园世界。<br
            class="desktop-break"
          />走进校园，与此刻在线的同伴相遇。
        </p>
        <a
          class="download"
          href="https://github.com/saurlax/dlut-online/releases"
          >下载客户端 <span aria-hidden="true">↗</span></a
        >
        <p class="platforms">支持 Windows 与 macOS</p>
      </section>
      <section class="online-section" aria-labelledby="online-title">
        <div class="section-heading">
          <div>
            <p class="eyebrow">此刻的校园</p>
            <h2 id="online-title">在线情况</h2>
          </div>
          <span class="status" :class="{ live }" role="status"
            ><span class="status-dot" />{{ status }}</span
          >
        </div>
        <div class="overview">
          <div class="total-block">
            <p class="metric-label">总在线人数</p>
            <div class="total-value">
              {{ live ? data?.total : "—" }}<span v-if="live">人</span>
            </div>
          </div>
          <div class="status-copy">
            <p>{{ explanation }}</p>
            <p class="timestamp">最后上报：{{ updated }}</p>
          </div>
        </div>
        <div class="campus-grid">
          <article
            v-for="campus in campuses"
            :key="campus.id"
            class="campus-card"
          >
            <div class="campus-top">
              <span class="campus-number">{{ campus.number }}</span
              ><span class="campus-state">{{
                live ? "当前在线" : "等待更新"
              }}</span>
            </div>
            <h3>{{ campus.name }}</h3>
            <p class="campus-count">
              {{ live ? data?.campuses?.[campus.id] : "—"
              }}<span v-if="live">人</span>
            </p>
          </article>
        </div>
      </section>
    </main>
    <footer><span>DLUT Online</span><span>校园探索，从这里开始。</span></footer>
  </div>
</template>
