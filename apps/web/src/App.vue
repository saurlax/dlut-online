<script setup lang="ts">
import { NButton, NConfigProvider, NGlobalStyle, zhCN, type GlobalThemeOverrides } from "naive-ui";
import { computed, ref } from "vue";
import mainBuilding from "./assets/main-building.jpg";
import library from "./assets/library.jpg";
import garden from "./assets/campus-garden.jpg";

const themeOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: "#0041b7", primaryColorHover: "#245cce",
    primaryColorPressed: "#00338f", primaryColorSuppl: "#0041b7",
    borderRadius: "0px", bodyColor: "#f6f5f1", textColorBase: "#142338",
    textColor2: "#586371", fontFamily: '"PingFang SC", "Microsoft YaHei", sans-serif',
  },
  Button: { heightLarge: "56px", fontSizeLarge: "14px", fontWeight: "500" },
};
const downloadUrl = "https://github.com/saurlax/dlut-online/releases";
const paused = ref(false);
const scenes = [
  { title: "主楼", image: mainBuilding, alt: "仰望阳光下的大工主楼石材立面与门廊", caption: "从熟悉的轮廓，认出心里的校园。", number: "01" },
  { title: "令希图书馆", image: library, alt: "蓝天下令希图书馆的红砖立面与宽阔台阶", caption: "走过长长的台阶，再赴一场与知识的约定。", number: "02" },
  { title: "校园一隅", image: garden, alt: "主楼旁的绿荫和洒满阳光的石板小路", caption: "不必赶路，在树影里多停留一会儿。", number: "03" },
];
const selected = ref(0);
const currentScene = computed(() => scenes[selected.value]!);
</script>

<template>
  <n-config-provider :locale="zhCN" :theme-overrides="themeOverrides">
    <n-global-style />
    <div class="landing">
      <header class="site-header">
        <a class="brand" href="#home" aria-label="DLUT Online 首页">DLUT <span>Online</span></a>
        <nav aria-label="主导航">
          <a href="#world">走进大工</a>
          <a href="#landscapes">校园印象</a>
          <n-button tag="a" href="#download" ghost color="#ffffff" class="nav-download">下载客户端 <span aria-hidden="true">↗</span></n-button>
        </nav>
      </header>
      <main>
        <section id="home" class="hero" aria-labelledby="hero-title">
          <div class="hero-background" :class="{ 'is-paused': paused }" aria-hidden="true">
            <img :src="mainBuilding" width="1280" height="960" alt="" fetchpriority="high" />
          </div>
          <div class="hero-shade" />
          <div class="hero-content">
            <p class="eyebrow light">DALIAN UNIVERSITY OF TECHNOLOGY</p>
            <p class="hero-category">第一人称校园 MMORPG</p>
            <h1 id="hero-title">大工，再相逢。</h1>
            <p class="hero-description">那些走过的路，那些遇见的人。<br class="mobile-break" />在这里，续写我们的校园故事。</p>
            <n-button tag="a" :href="downloadUrl" type="primary" size="large" class="primary-cta">走进 DLUT Online <span aria-hidden="true">↗</span></n-button>
            <p class="platforms">Windows / macOS 桌面客户端</p>
          </div>
          <div class="hero-bottom">
            <a href="#world" class="scroll-link"><span class="scroll-line" aria-hidden="true" />向下探索</a>
            <div class="motion-tools">
              <span>校园实景</span>
              <n-button text color="#ffffff" class="motion-toggle" :aria-pressed="paused" :aria-label="paused ? '播放背景动效' : '暂停背景动效'" @click="paused = !paused">
                <span aria-hidden="true">{{ paused ? '▷' : 'Ⅱ' }}</span>{{ paused ? '播放动效' : '暂停动效' }}
              </n-button>
            </div>
          </div>
        </section>

        <section id="world" class="world-section" aria-labelledby="world-title">
          <div class="world-heading">
            <p class="eyebrow">01 / 一个关于大工的世界</p>
            <h2 id="world-title">熟悉的校园，<br />未完的故事。</h2>
            <div class="world-copy">
              <p>一条走过无数次的小路，一栋抬头就能认出的楼。<br />关于大工的记忆，总有一个具体的坐标。</p>
              <p>DLUT Online 希望把这些坐标连接成一个可以共同走进的世界。以整个大连理工大学为主题，让校园里的探索与相逢，延续到屏幕的另一端。</p>
            </div>
          </div>
          <div class="world-details">
            <figure class="garden-photo"><img :src="garden" alt="校园小路上的阳光与树影" width="1280" height="960" loading="lazy" /><figcaption>光影之间，都是校园日常。<span>校园实景</span></figcaption></figure>
            <div class="world-notes">
              <div><span class="note-number">01</span><h3>以你的视角</h3><p>第一人称走进校园，<br />重新发现熟悉的风景。</p></div>
              <div><span class="note-number">02</span><h3>让相遇继续</h3><p>一个共同在线的世界，<br />让独自漫步也有相逢的可能。</p></div>
              <div><span class="note-number">03</span><h3>一起慢慢建成</h3><p>从一处风景到一座校园，<br />让这个开源世界不断生长。</p></div>
            </div>
          </div>
        </section>

        <section id="landscapes" class="landscapes" aria-labelledby="landscapes-title">
          <div class="landscapes-heading"><div><p class="eyebrow light">02 / 校园印象</p><h2 id="landscapes-title">总有一处风景，<br />让你想起大工。</h2></div><p class="landscapes-intro">目光所及，皆是回忆。<br />从真实的校园，寻找这个世界的灵感。</p></div>
          <div class="scene-layout">
            <figure class="scene-photo"><img :src="currentScene.image" :alt="currentScene.alt" width="1280" height="960" loading="lazy" /><figcaption>大连理工大学 / 校园实景</figcaption></figure>
            <div class="scene-details">
              <span class="scene-number" aria-hidden="true">{{ currentScene.number }}</span>
              <div class="scene-copy" aria-live="polite"><h3>{{ currentScene.title }}</h3><p>{{ currentScene.caption }}</p></div>
              <div class="scene-picker" role="group" aria-label="选择校园实景">
                <n-button v-for="(scene, index) in scenes" :key="scene.number" text :color="selected === index ? '#ffffff' : '#aeb9c9'" :aria-pressed="selected === index" :class="{ selected: selected === index }" @click="selected = index"><span class="picker-number">{{ scene.number }}</span>{{ scene.title }}<span class="picker-arrow" aria-hidden="true">↗</span></n-button>
              </div>
            </div>
          </div>
        </section>

        <section id="download" class="download-section" aria-labelledby="download-title">
          <p class="eyebrow light">属于我们的校园世界</p>
          <h2 id="download-title">下一次相逢，<br />就在大工。</h2>
          <p class="download-copy">下载 DLUT Online，开启你的校园漫步。</p>
          <n-button tag="a" :href="downloadUrl" size="large" color="#ffffff" text-color="#0041b7" class="primary-cta">下载桌面客户端 <span aria-hidden="true">↗</span></n-button>
          <p class="platforms">Windows x86_64 / macOS universal</p>
          <p class="development-note">项目持续建设中，欢迎体验当前版本。</p>
        </section>
      </main>
      <footer><a class="brand" href="#home">DLUT <span>Online</span></a><p>让校园里的故事，继续发生。</p><a href="https://github.com/saurlax/dlut-online">GitHub 开源项目 <span aria-hidden="true">↗</span></a></footer>
    </div>
  </n-config-provider>
</template>
