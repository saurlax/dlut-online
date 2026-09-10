<script setup lang="ts">
import { NButton, NCard, NConfigProvider, NFlex, NGlobalStyle, NGrid, NGi, NImage, NList, NListItem, NPageHeader, NP, NRadioButton, NRadioGroup, NTag, NText, NThing, zhCN, type GlobalThemeOverrides } from "naive-ui";
import { computed, onMounted, onUnmounted, ref } from "vue";
import mainBuilding from "./assets/main-building.jpg";
import library from "./assets/library.jpg";
import garden from "./assets/campus-garden.jpg";
import campusFilm from "./assets/campus-film.mp4";
import filmPoster from "./assets/campus-film-poster.jpg";
import { downloads, detectDesktopPlatform } from "./downloads";

const themeOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: "#0041b7", primaryColorHover: "#245cce",
    primaryColorPressed: "#00338f", primaryColorSuppl: "#0041b7",
    borderRadius: "4px", bodyColor: "#f6f5f1", textColorBase: "#142338",
    textColor2: "#586371", fontFamily: '"PingFang SC", "Microsoft YaHei", sans-serif',
  },
  Card: { borderRadius: "8px" },
  PageHeader: { titleFontSize: "28px" },
  List: { color: "transparent" },
  Button: { heightLarge: "56px", fontSizeLarge: "14px", fontWeight: "500" },
};
const isDownloadPage = /^\/download\/?$/.test(window.location.pathname);
const platform = detectDesktopPlatform(navigator.userAgent, navigator.platform, navigator.maxTouchPoints);
const recommended = platform ? downloads[platform] : null;
const downloadUrl = recommended?.url ?? "/download";
const downloadLabel = recommended?.button ?? "选择桌面版本";
function goHome() { window.location.assign("/"); }
if (isDownloadPage) document.title = "下载客户端 | DLUT Online";
const video = ref<HTMLVideoElement | null>(null);
const videoFailed = ref(false);
let motionPreference: MediaQueryList | undefined;

function syncPlayback() {
  if (!video.value) return;
  if (motionPreference?.matches || document.hidden) {
    video.value.pause();
  } else {
    void video.value.play().catch(() => { /* Keep a still frame when autoplay is unavailable. */ });
  }
}

onMounted(() => {
  motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)");
  motionPreference.addEventListener("change", syncPlayback);
  document.addEventListener("visibilitychange", syncPlayback);
  syncPlayback();
});
onUnmounted(() => {
  motionPreference?.removeEventListener("change", syncPlayback);
  document.removeEventListener("visibilitychange", syncPlayback);
});
const scenes = [
  { title: "主楼", image: mainBuilding, alt: "仰望阳光下的大工主楼石材立面与门廊", caption: "主楼以浅色石材立面、连续窗列和入口门廊形成鲜明的建筑轮廓。", number: "01" },
  { title: "令希图书馆", image: library, alt: "蓝天下令希图书馆的红砖立面与宽阔台阶", caption: "红砖与玻璃构成令希图书馆的正面，宽阔台阶连接馆前广场。", number: "02" },
  { title: "校园一隅", image: garden, alt: "主楼旁的绿荫和洒满阳光的石板小路", caption: "主楼旁的石板步道与绿化相接，树荫和建筑共同构成校园的步行空间。", number: "03" },
];
const selected = ref(0);
const currentScene = computed(() => scenes[selected.value]!);
</script>

<template>
  <n-config-provider :locale="zhCN" :theme-overrides="themeOverrides">
    <n-global-style />
    <div class="landing" :class="{ 'download-page': isDownloadPage }">
      <header class="site-header"><n-flex justify="space-between" align="center" :wrap="false">
        <a class="brand" href="/" aria-label="DLUT Online 首页">DLUT <span>Online</span></a>
        <nav aria-label="主导航">
          <n-button tag="a" href="/download" ghost color="#ffffff" class="nav-download">下载客户端 <span aria-hidden="true">↗</span></n-button>
        </nav>
      </n-flex></header>
      <main v-if="isDownloadPage" class="download-content">
        <n-page-header @back="goHome">
          <template #back><n-button text aria-label="返回首页">←</n-button></template>
          <template #title><h1 class="download-title">选择你的桌面版本</h1></template>
          <template #header><n-text depth="3">DLUT Online</n-text></template>
          <template #footer><n-text depth="3">支持 Windows x86_64 和 macOS Universal。</n-text></template>
        </n-page-header>
        <n-grid cols="1 m:2" responsive="screen" :x-gap="24" :y-gap="24" class="download-options">
          <n-gi v-for="(item, key) in downloads" :key="key">
            <n-card size="large" :title="item.label" :class="{ recommended: platform === key }" class="download-option">
              <template #header-extra><n-tag v-if="platform === key" type="primary" size="small" :bordered="false">当前系统</n-tag></template>
              <n-text depth="3">{{ item.architecture }}</n-text>
              <template #action><n-button tag="a" :href="item.url" type="primary" size="large" block>{{ item.button }} <span aria-hidden="true">↗</span></n-button></template>
            </n-card>
          </n-gi>
        </n-grid>
        <n-p depth="3" class="download-help">通过 GitHub Releases 获取对应系统的客户端安装包。</n-p>
      </main>
      <main v-else>
        <section id="home" class="hero" aria-labelledby="hero-title">
          <div class="hero-background" aria-hidden="true">
            <img v-if="videoFailed" :src="filmPoster" width="856" height="480" alt="" />
            <video v-else ref="video" :src="campusFilm" :poster="filmPoster" muted loop playsinline preload="metadata" @error="videoFailed = true" />
          </div>
          <div class="hero-shade" />
          <div class="hero-content">
            <h1 id="hero-title">大工，再相逢</h1>
            <p class="hero-description">探索校园、查看地图，与其他玩家一同漫游。</p>
            <n-button tag="a" :href="downloadUrl" type="primary" size="large" class="primary-cta">{{ downloadLabel }} <span aria-hidden="true">↗</span></n-button>
            <n-button text tag="a" class="other-downloads" color="#e0e9fa" href="/download">其他下载</n-button>
          </div>
        </section>

        <section id="world" class="world-section" aria-labelledby="world-title">
          <p class="eyebrow">01 / 游戏介绍</p>
          <n-grid cols="1 m:2" responsive="screen" :x-gap="64" :y-gap="28" class="world-heading"><n-gi>
            <h2 id="world-title">第一人称<br />校园探索</h2>
            </n-gi><n-gi><div class="world-copy">
              <p>DLUT Online 是以大连理工大学为主题的多人在线校园游戏。你将以第一人称进入校园，在教学楼、广场与道路之间自由行走，观察身边的建筑与环境。</p>
              <p>通过校园地图查看位置与建筑分布，选择校区进行传送。进入校园后，你可以看到同校区的其他玩家，在共同的场景中探索。</p>
            </div></n-gi>
          </n-grid>
          <n-grid cols="1 m:2" responsive="screen" :x-gap="64" :y-gap="32" class="world-details"><n-gi>
            <figure class="garden-photo"><n-image :src="garden" alt="校园小路上的阳光与树影" object-fit="cover" lazy preview-disabled /><figcaption>主楼旁的步行空间<span>校园实景</span></figcaption></figure>
            </n-gi><n-gi>
              <n-list class="world-notes">
                <n-list-item><n-thing title="自由漫游" description="自由行走与奔跑，转动视角观察校园环境。"><template #avatar><n-tag :bordered="false" type="primary">01</n-tag></template></n-thing></n-list-item>
                <n-list-item><n-thing title="校园地图" description="查看位置与建筑分布，通过地图切换校区。"><template #avatar><n-tag :bordered="false" type="primary">02</n-tag></template></n-thing></n-list-item>
                <n-list-item><n-thing title="多人同游" description="实时看到同校区玩家，在同一场景中自由探索。"><template #avatar><n-tag :bordered="false" type="primary">03</n-tag></template></n-thing></n-list-item>
              </n-list>
            </n-gi>
          </n-grid>
        </section>

        <section id="landscapes" class="landscapes" aria-labelledby="landscapes-title">
          <n-flex class="landscapes-heading" justify="space-between" align="end" :size="32"><div><p class="eyebrow light">02 / 场景介绍</p><h2 id="landscapes-title">校园建筑与环境</h2></div><p class="landscapes-intro">以大工校园的建筑、道路和公共空间为场景主题。<br />以下实景展示校园的建筑特征与空间环境。</p></n-flex>
          <n-grid cols="1 m:3" responsive="screen" :x-gap="40" :y-gap="28" class="scene-layout" item-responsive><n-gi span="1 m:2">
            <figure class="scene-photo"><n-image :src="currentScene.image" :alt="currentScene.alt" object-fit="cover" lazy preview-disabled /><figcaption>大连理工大学 / 校园实景</figcaption></figure>
            </n-gi><n-gi><n-flex vertical class="scene-details" :size="24">
              <span class="scene-number" aria-hidden="true">{{ currentScene.number }}</span>
              <div class="scene-copy" aria-live="polite"><h3>{{ currentScene.title }}</h3><p>{{ currentScene.caption }}</p></div>
              <n-radio-group v-model:value="selected" name="campus-scene" aria-label="选择校园实景" class="scene-picker" :theme-overrides="{ buttonColor: '#0b1727', buttonColorActive: '#233b60', buttonTextColor: '#cad5e6', buttonTextColorActive: '#ffffff', buttonBorderColor: '#51627a', buttonBorderColorActive: '#8aafff' }">
                <n-flex :size="8"><n-radio-button v-for="(scene, index) in scenes" :key="scene.number" :value="index">{{ scene.title }}</n-radio-button></n-flex>
              </n-radio-group>
            </n-flex></n-gi>
          </n-grid>
        </section>

        <section id="download" class="download-section" aria-labelledby="download-title">
          <p class="eyebrow light">客户端下载</p>
          <h2 id="download-title">下载 DLUT Online</h2>
          <p class="download-copy">选择适合你设备的桌面客户端。</p>
          <n-button tag="a" href="/download" size="large" color="#ffffff" text-color="#0041b7" class="primary-cta">下载桌面客户端 <span aria-hidden="true">↗</span></n-button>
          <p class="platforms">Windows x86_64 / macOS universal</p>
        </section>
      </main>
      <footer><n-flex justify="space-between" align="center"><a class="brand" href="/">DLUT <span>Online</span></a><n-button text tag="a" color="#c1cbda" href="https://github.com/saurlax/dlut-online">GitHub 开源项目 <span aria-hidden="true">↗</span></n-button></n-flex></footer>
    </div>
  </n-config-provider>
</template>
