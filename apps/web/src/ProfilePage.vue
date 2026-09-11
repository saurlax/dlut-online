<script setup lang="ts">
import { ref, watch } from "vue";
import { NAlert, NButton, NCard, NDescriptions, NDescriptionsItem, NDivider, NForm, NFormItem, NInput, NP, NSpin } from "naive-ui";
import { account, authReady, authError, AuthError, changeEmail, logout, restoreSession, updateDisplayName } from "./auth";

const displayName = ref("");
const newEmail = ref("");
const busy = ref(false);
const error = ref("");
const notice = ref("");
watch(account, (value) => { displayName.value = value?.display_name ?? ""; }, { immediate: true });
async function submit(kind: "name" | "email") {
  if (busy.value) return;
  error.value = ""; notice.value = "";
  const name = displayName.value.trim();
  const email = newEmail.value.trim();
  if (kind === "name" && (!name || [...name].length > 64)) { error.value = "显示名称须为 1 至 64 个字符。"; return; }
  if (kind === "email" && (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.toLowerCase() === account.value?.email.toLowerCase())) { error.value = "请输入与当前邮箱不同的有效邮箱。"; return; }
  busy.value = true;
  try {
    if (kind === "name") {
      await updateDisplayName(name);
      notice.value = "显示名称已保存。";
    } else {
      await changeEmail(email);
      newEmail.value = "";
      notice.value = "更换邮箱请求已提交。请查收新邮箱中的邮件，打开链接并输入当前密码完成确认；确认前仍使用原邮箱。完成后请使用新邮箱重新登录。";
    }
  } catch (e) {
    if (e instanceof AuthError && e.status === 401) { logout(); error.value = "登录已失效，请重新登录。"; }
    else error.value = e instanceof Error ? e.message : "操作失败，请重试。";
  } finally { busy.value = false; }
}
</script>

<template>
  <main class="account-content profile-content">
    <n-card title="个人资料" size="large">
      <n-spin v-if="!authReady" description="正在检查登录状态" />
      <template v-else>
        <n-alert v-if="error || authError" type="error" class="account-message" role="alert">{{ error || authError }}</n-alert>
        <n-alert v-if="notice" type="success" class="account-message" role="status">{{ notice }}</n-alert>
        <template v-if="account">
          <n-descriptions :column="1" label-placement="top">
            <n-descriptions-item label="账号 ID">{{ account.id }}</n-descriptions-item>
            <n-descriptions-item label="用户名">{{ account.username }}</n-descriptions-item>
            <n-descriptions-item label="当前邮箱">{{ account.email }}</n-descriptions-item>
            <n-descriptions-item label="邮箱状态">{{ account.verified ? '已验证' : '未验证' }}</n-descriptions-item>
            <n-descriptions-item v-if="account.created" label="注册时间">{{ new Date(account.created).toLocaleString('zh-CN') }}</n-descriptions-item>
          </n-descriptions>
          <n-divider />
          <n-form @submit.prevent="submit('name')">
            <n-form-item label="显示名称"><n-input v-model:value="displayName" :disabled="busy" placeholder="你在游戏中显示的名字" /></n-form-item>
            <n-button attr-type="submit" type="primary" :loading="busy" :disabled="displayName.trim() === account.display_name">保存显示名称</n-button>
          </n-form>
          <n-divider />
          <n-form @submit.prevent="submit('email')">
            <n-form-item label="新邮箱"><n-input v-model:value="newEmail" :disabled="busy" :input-props="{ type: 'email', autocomplete: 'email' }" placeholder="请输入新邮箱" /></n-form-item>
            <n-p depth="3">新邮箱验证通过后生效，确认时需要当前密码。</n-p>
            <n-button attr-type="submit" :loading="busy">发送更换邮箱邮件</n-button>
          </n-form>
          <n-divider />
          <n-button type="error" block :disabled="busy" @click="logout(); error = ''; notice = ''; newEmail = ''">退出登录</n-button>
        </template>
        <template v-else-if="authError"><n-button @click="restoreSession">重试登录状态</n-button></template>
        <template v-else><n-p>登录后查看和管理你的个人资料。</n-p><n-button tag="a" href="/login" type="primary">前往登录</n-button></template>
      </template>
    </n-card>
  </main>
</template>

<style scoped>
.profile-content { overflow-wrap: anywhere; }
</style>
