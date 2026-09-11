<script setup lang="ts">
import { computed, reactive, ref } from "vue";
import { NAlert, NButton, NCard, NFlex, NForm, NFormItem, NInput, NP, NSpin, type FormInst, type FormRules } from "naive-ui";
import { account, authReady, AuthError, login, request } from "./auth";

const props = defineProps<{ register: boolean }>();
const form = ref<FormInst | null>(null);
const model = reactive({ email: "", username: "", display_name: "", password: "", passwordConfirm: "" });
const busy = ref(false);
const error = ref("");
const notice = ref("");
const created = ref(false);
const heading = computed(() => account.value ? "已登录" : props.register ? "创建账号" : "登录");
const rules: FormRules = {
  email: [{ required: true, message: "请输入邮箱", trigger: ["blur", "input"] }, { type: "email", message: "请输入有效邮箱", trigger: "blur" }],
  username: { required: true, pattern: /^[A-Za-z0-9_-]{1,64}$/, message: "用户名仅支持字母、数字、下划线和连字符，最多 64 个字符", trigger: "blur" },
  display_name: { required: true, validator: (_rule, value: string) => value.trim().length > 0 && [...value.trim()].length <= 64, message: "请输入 1 至 64 个字符的显示名", trigger: "blur" },
  password: { required: true, validator: (_rule, value: string) => value.length > 0 && (!props.register || value.length >= 8), message: props.register ? "密码至少 8 个字符" : "请输入密码", trigger: "blur" },
  passwordConfirm: { required: true, validator: (_rule, value: string) => value === model.password, message: "两次输入的密码不一致", trigger: ["blur", "input"] },
};
function message(e: unknown) { return e instanceof Error ? e.message : "操作失败，请重试。"; }

async function sendVerification() {
  busy.value = true; error.value = ""; notice.value = "";
  try {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(model.email.trim())) throw new Error("请先填写有效邮箱。");
    await request("/api/collections/users/request-verification", { email: model.email.trim() });
    notice.value = "验证邮件请求已提交。请检查收件箱及垃圾邮件，完成验证后再登录。";
  } catch (e) { error.value = message(e); }
  finally { busy.value = false; }
}
async function submit() {
  if (busy.value) return;
  try { await form.value?.validate(); } catch { return; }
  busy.value = true; error.value = ""; notice.value = "";
  try {
    if (props.register) {
      await request("/api/collections/users/records", { ...model, email: model.email.trim(), display_name: model.display_name.trim() });
      created.value = true;
      model.password = ""; model.passwordConfirm = "";
      try {
        await request("/api/collections/users/request-verification", { email: model.email.trim() });
        notice.value = "账号已创建。请查看验证邮件，完成邮箱验证后再登录。";
      } catch { error.value = "账号已创建，但验证邮件请求失败，请稍后重发。"; }
    } else {
      await login(model.email, model.password);
      window.location.assign("/profile");
      model.password = "";
    }
  } catch (e) {
    if (e instanceof AuthError && e.status === 400) {
      error.value = props.register ? "注册未完成，请检查邮箱、用户名是否已被使用，以及密码是否符合要求。" : "登录失败，请检查邮箱和密码，并确认邮箱已验证、账号可用。";
    } else if (e instanceof AuthError && e.status === 403) {
      error.value = "暂时无法登录，请确认邮箱已验证且账号可用。";
    } else error.value = message(e);
  } finally { busy.value = false; }
}
</script>

<template>
  <main class="account-content">
    <n-card :title="heading" size="large">
      <n-spin v-if="!authReady" description="正在检查登录状态" />
      <template v-else>
        <n-alert v-if="error" type="error" class="account-message" role="alert">{{ error }}</n-alert>
        <n-alert v-if="notice" type="success" class="account-message" role="status">{{ notice }}</n-alert>
        <template v-if="account">
          <n-p>你好，{{ account.display_name }}</n-p>
          <n-flex vertical :size="16">
            <n-button tag="a" href="/profile" type="primary" block>个人资料</n-button>
          </n-flex>
        </template>
        <template v-else-if="created">
          <n-p>注册邮箱：{{ model.email }}</n-p>
          <n-flex vertical :size="16">
            <n-button tag="a" href="/login" type="primary" block>已验证，前往登录</n-button>
            <n-button text :loading="busy" @click="sendVerification">重新发送验证邮件</n-button>
          </n-flex>
        </template>
        <template v-else>
          <n-p depth="3">{{ register ? '创建账号后验证邮箱，即可登录网站和游戏。' : '使用你的 DLUT Online 账号。' }}</n-p>
          <n-form ref="form" :model="model" :rules="rules" @submit.prevent="submit">
            <n-form-item label="邮箱" path="email"><n-input v-model:value="model.email" :input-props="{ type: 'email', autocomplete: 'email', inputmode: 'email' }" placeholder="请输入邮箱" :disabled="busy" /></n-form-item>
            <n-form-item v-if="register" label="用户名" path="username"><n-input v-model:value="model.username" :maxlength="64" :input-props="{ autocomplete: 'username' }" placeholder="字母、数字、下划线或连字符" :disabled="busy" /></n-form-item>
            <n-form-item v-if="register" label="显示名" path="display_name"><n-input v-model:value="model.display_name" :maxlength="64" placeholder="你在游戏中显示的名字" :disabled="busy" /></n-form-item>
            <n-form-item label="密码" path="password"><n-input v-model:value="model.password" type="password" show-password-on="click" :input-props="{ autocomplete: register ? 'new-password' : 'current-password' }" :placeholder="register ? '至少 8 个字符' : '请输入密码'" :disabled="busy" /></n-form-item>
            <n-form-item v-if="register" label="确认密码" path="passwordConfirm"><n-input v-model:value="model.passwordConfirm" type="password" show-password-on="click" :input-props="{ autocomplete: 'new-password' }" placeholder="再次输入密码" :disabled="busy" /></n-form-item>
            <n-button attr-type="submit" type="primary" block :loading="busy">{{ register ? '注册' : '登录' }}</n-button>
          </n-form>
          <n-flex justify="space-between" class="account-links" :size="16">
            <n-button text tag="a" :href="register ? '/login' : '/register'" type="primary">{{ register ? '已有账号，登录' : '没有账号？注册' }}</n-button>
            <n-button v-if="!register" text :disabled="busy" @click="sendVerification">重发验证邮件</n-button>
          </n-flex>
        </template>
      </template>
    </n-card>
  </main>
</template>
