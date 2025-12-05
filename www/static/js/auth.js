// 认证相关功能
const AuthManager = {
    // 初始化认证页面
    initAuthPage: function(page) {
        console.log(`初始化认证页面: ${page}`);
        
        switch(page) {
            case 'login':
                this.initLoginPage();
                break;
            case 'register':
                this.initRegisterPage();
                break;
            case 'forgot-password':
                this.initForgotPasswordPage();
                break;
            default:
                console.error('未知的认证页面:', page);
        }
    },

    // 登录页面初始化
    initLoginPage: function() {
        const form = document.getElementById('login-form');
        if (!form) {
            console.error('登录表单未找到');
            return;
        }

        // 清理可能存在的旧Turnstile实例
        this.cleanupTurnstile();
        
        // 初始化Turnstile状态
        window.turnstileToken = null;

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('login-username').value;
            const password = document.getElementById('login-password').value;
            
            // 检查Turnstile验证
            if (!window.turnstileToken) {
                alert('请完成人机验证');
                return;
            }
            
            try {
                const result = await fetchAPI('login', 'POST', { 
                    username, 
                    password,
                    turnstile_token: window.turnstileToken
                });
                if (result.code != 0) {
                    alert('登录失败: ' + result.message);
                    // 重置Turnstile
                    if (window.turnstile) {
                        window.turnstile.reset();
                    }
                    return;
                }
                // 传递username给Auth.setToken
                Auth.setToken(result.token, result.username);
                showApp();
            } catch (error) {
                alert('登录失败: ' + error.message);
                // 重置Turnstile
                if (window.turnstile) {
                    window.turnstile.reset();
                }
            }
        });
        
        // 注册链接
        document.querySelectorAll('[data-auth-page="register"]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                loadAuthPage('register');
            });
        });
        
        // 忘记密码链接
        document.querySelectorAll('[data-auth-page="forgot-password"]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                loadAuthPage('forgot-password');
            });
        });
        
        // 确保Turnstile正确初始化
        this.ensureTurnstileInitialized();
    },

    // 注册页面初始化
    initRegisterPage: function() {
        const form = document.getElementById('register-form');
        const smsBtn = document.getElementById('send-sms-btn');
        
        if (!form || !smsBtn) {
            console.error('注册表单元素未找到');
            return;
        }
        
        // 发送验证码
        smsBtn.addEventListener('click', async () => {
            const phone = document.getElementById('reg-phone').value;
            if (!phone) {
                alert('请输入手机号');
                return;
            }
            // 简单手机号正则校验（以1开头，11位数字）
            const phonePattern = /^1\d{10}$/;
            if (!phonePattern.test(phone)) {
                alert('请输入有效的手机号');
                return;
            }
            try {
                const data = await fetchAPI('send-sms', 'POST', { phone: phone, type: 'reg' });
                this.startCountdown(smsBtn, 60);
                console.log('验证码发送结果:', data);
                if (data.code == 0 ){
                    alert('验证码已发送！');
                }else{
                    alert(data.message);
                }
            } catch (error) {
                alert('发送失败: ' + error.message);
            }
        });
        
        // 注册提交
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('reg-username').value;
            const phone = document.getElementById('reg-phone').value;
            const code = document.getElementById('reg-code').value;
            const password = document.getElementById('reg-password').value;
            const confirmPassword = document.getElementById('reg-confirm-password').value;
            
            if (password !== confirmPassword) {
                alert('两次输入的密码不一致');
                return;
            }
            
            try {
                const result = await fetchAPI('register', 'POST', {
                    username,
                    phone,
                    code,
                    password
                });
                if (result.code != 0){
                    alert('注册失败:' + result.message);
                    return;
                }
                alert('注册成功');
                // 传递username给Auth.setToken
                Auth.setToken(result.token, result.username);
                showApp();
            } catch (error) {
                alert('注册失败: ' + error.message);
            }
        });
        
        // 返回登录链接
        document.querySelectorAll('[data-auth-page="login"]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                loadAuthPage('login');
            });
        });
    },

    // 忘记密码页面初始化
    initForgotPasswordPage: function() {
        const form = document.getElementById('forgot-password-form');
        if (!form) {
            console.error('忘记密码表单未找到');
            return;
        }
        
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            try {
                await fetchAPI('reset-password', 'POST', {
                    phone: document.getElementById('reset-phone').value,
                    code: document.getElementById('reset-code').value,
                    newPassword: document.getElementById('new-password').value
                });
                
                alert('密码重置成功，请重新登录');
                loadAuthPage('login');
            } catch (error) {
                alert('重置失败: ' + error.message);
            }
        });
        
        // 返回登录链接
        document.querySelectorAll('[data-auth-page="login"]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                loadAuthPage('login');
            });
        });
    },

    // 倒计时函数
    startCountdown: function(button, seconds) {
        button.disabled = true;
        let remaining = seconds;
        
        button.textContent = `${remaining}秒后重试`;
        
        const timer = setInterval(() => {
            remaining--;
            button.textContent = `${remaining}秒后重试`;
            
            if (remaining <= 0) {
                clearInterval(timer);
                button.textContent = '发送验证码';
                button.disabled = false;
            }
        }, 1000);
    },

    // 清理Turnstile实例
    cleanupTurnstile: function() {
        // 移除可能存在的旧Turnstile iframe
        const turnstileIframes = document.querySelectorAll('iframe[src*="challenges.cloudflare.com"]');
        turnstileIframes.forEach(iframe => {
            if (iframe.parentNode) {
                iframe.parentNode.removeChild(iframe);
            }
        });
        
        // 清理Turnstile容器
        const turnstileContainers = document.querySelectorAll('.cf-turnstile');
        turnstileContainers.forEach(container => {
            // 保留容器但清空内容
            container.innerHTML = '';
        });
        
        // 重置Turnstile状态
        if (window.turnstile && typeof window.turnstile.reset === 'function') {
            try {
                window.turnstile.reset();
            } catch (e) {
                // console.log('Turnstile重置失败:');
            }
        }
        
        console.log('Turnstile清理完成');
    },

    // 确保Turnstile正确初始化
    ensureTurnstileInitialized: function() {
        // 等待Turnstile脚本加载完成
        const checkTurnstile = () => {
            if (typeof turnstile !== 'undefined') {
                console.log('Turnstile已加载，检查组件状态');
                
                // 检查是否有Turnstile容器但没有iframe
                const containers = document.querySelectorAll('.cf-turnstile');
                containers.forEach(container => {
                    if (!container.querySelector('iframe')) {
                        console.log('重新渲染Turnstile组件');
                        turnstile.render(container, {
                            sitekey: '0x4AAAAAABuy2hEN5Jto29ic',
                            callback: window.onTurnstileSuccess,
                            'expired-callback': window.onTurnstileExpired,
                            'error-callback': window.onTurnstileError
                        });
                    }
                });
            } else {
                console.log('Turnstile未加载，等待中...');
                setTimeout(checkTurnstile, 500);
            }
        };
        
        // 开始检查
        setTimeout(checkTurnstile, 1000);
    }
};

// // 暴露到全局
// window.AuthManager = AuthManager;
// window.initAuthPage = AuthManager.initAuthPage.bind(AuthManager);

// 在auth.js末尾添加以下代码，确保所有函数都能被正确调用
document.addEventListener('DOMContentLoaded', function() {
    // 自动绑定认证页面的链接点击事件
    document.body.addEventListener('click', function(e) {
        // 处理注册账号链接
        if (e.target.closest('[data-auth-page="register"]')) {
            e.preventDefault();
            loadAuthPage('register');
        }
        
        // 处理忘记密码链接
        if (e.target.closest('[data-auth-page="forgot-password"]')) {
            e.preventDefault();
            loadAuthPage('forgot-password');
        }
    });
});

// 确保函数全局可用
window.AuthManager = AuthManager;
window.loadAuthPage = AuthManager.loadAuthPage;
// window.showAuth = showAuth;

// Turnstile回调函数
window.onTurnstileSuccess = function(token) {
    // console.log('Turnstile验证成功:', token);
    window.turnstileToken = token;
    const loginBtn = document.getElementById('login-btn');
    if (loginBtn) {
        loginBtn.disabled = false;
        console.log('登录按钮已启用');
    } else {
        console.error('未找到登录按钮');
    }
};

window.onTurnstileExpired = function() {
    // console.log('Turnstile验证已过期');
    window.turnstileToken = null;
    const loginBtn = document.getElementById('login-btn');
    if (loginBtn) {
        loginBtn.disabled = true;
    }
    // 重新初始化Turnstile
    setTimeout(() => {
        if (window.turnstile && typeof window.turnstile.render === 'function') {
            const containers = document.querySelectorAll('.cf-turnstile');
            containers.forEach(container => {
                if (!container.querySelector('iframe')) {
                    window.turnstile.render(container, {
                        sitekey: '0x4AAAAAABuy2hEN5Jto29ic',
                        callback: window.onTurnstileSuccess,
                        'expired-callback': window.onTurnstileExpired,
                        'error-callback': window.onTurnstileError
                    });
                }
            });
        }
    }, 1000);
};

window.onTurnstileError = function() {
    console.log('Turnstile验证出错');
    console.log('请检查以下问题：');
    console.log('1. 域名配置是否正确');
    console.log('2. Sitekey是否有效');
    console.log('3. 网络连接是否正常');
    window.turnstileToken = null;
    const loginBtn = document.getElementById('login-btn');
    if (loginBtn) {
        loginBtn.disabled = true;
    }
};
