// 配置API基础地址
const API_BASE_URL = 'http://127.0.0.1/monitor/get';

// 认证管理对象
const Auth = {
    token: null,
    username: null, // 添加username字段
    
    init: function() {
        this.token = this.getTokenFromCookie();
        this.username = this.getUsernameFromCookie(); // 从cookie获取username
        this.updateUI();
    },
    
    getTokenFromCookie: function() {
        const match = document.cookie.match(/token=([^;]+)/);
        return match ? match[1] : null;
    },
    
    getUsernameFromCookie: function() {
        const match = document.cookie.match(/username=([^;]+)/);
        return match ? decodeURIComponent(match[1]) : null;
    },
    
    setToken: function(token, username = null, remember = true) {
        this.token = token;
        this.username = username;
        
        if (remember) {
            const expires = new Date();
            expires.setDate(expires.getDate() + 7);
            document.cookie = `token=${token}; expires=${expires.toUTCString()}; path=/`;
            console.log("设置token",token)
            if (username) {
                document.cookie = `username=${encodeURIComponent(username)}; expires=${expires.toUTCString()}; path=/`;
            }
        }
        this.updateUI();
    },
    
    clearToken: function() {
        this.token = null;
        this.username = null;
        document.cookie = 'token=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
        document.cookie = 'username=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
        this.hideModal();
        this.updateUI();
        showAuth('login');
    },
    
    updateUI: function() {
        const userInfo = document.getElementById('user-info');
        const guestInfo = document.getElementById('guest-info');
        const usernameDisplay = document.getElementById('username-display');
        
        if (this.token) {
            userInfo.style.display = 'block';
            guestInfo.style.display = 'none';
            
            // 如果有username，直接显示，否则通过API获取
            if (this.username && usernameDisplay) {
                usernameDisplay.textContent = this.username;
            } else {
                this.fetchUserInfo();
            }
        } else {
            userInfo.style.display = 'none';
            guestInfo.style.display = 'block';
        }
    },
    
    // 显示模态框
    showModal: function(title, content, buttons = [], compact = false) {
        const modal = document.getElementById('global-modal');
        const modalContent = document.getElementById('modal-content');
        
        modalContent.innerHTML = `
            <h3>${title}</h3>
            <div class="modal-body">${content}</div>
            <div class="modal-actions">
                ${buttons.map(btn => `
                    <button class="btn ${btn.primary ? '' : 'btn-secondary'}" 
                            onclick="${btn.action}">
                        ${btn.text}
                    </button>
                `).join('')}
            </div>
        `;
        // 先移除所有自定义紧凑class
        modalContent.classList.remove('compact', 'ultra-compact', 'phone-verify-compact', 'password-compact');
        // 根据内容类型决定使用哪种紧凑模式
        if (compact) {
            // 退出登录、确认类弹窗
            if (content.length < 50 && buttons.length <= 2) {
                modalContent.classList.add('ultra-compact');
            // 修改手机号弹窗
            } else if (title.includes('手机号')) {
                modalContent.classList.add('phone-verify-compact');
            // 修改密码弹窗
            } else if (title.includes('密码')) {
                modalContent.classList.add('password-compact');
            } else {
                modalContent.classList.add('compact');
            }
        }
        modal.style.display = 'flex';
    },
    
    hideModal: function() {
        document.getElementById('global-modal').style.display = 'none';
    },
    
    fetchUserInfo: function() {
        fetchAPI('user-info')
            .then(data => {
                this.username = data.username; // 保存username
                const usernameDisplay = document.getElementById('username-display');
                const profileUsername = document.getElementById('profile-username');
                
                if (usernameDisplay) {
                    usernameDisplay.textContent = data.username;
                }
                if (profileUsername) {
                    profileUsername.textContent = data.username;
                }
                
                // 更新cookie中的username
                const expires = new Date();
                expires.setDate(expires.getDate() + 7);
                document.cookie = `username=${encodeURIComponent(data.username)}; expires=${expires.toUTCString()}; path=/`;
            })
            .catch(() => this.clearToken());
    }
};

// API请求函数
async function fetchAPI(endpoint, method = 'GET', data = null) {
    const options = {
        method,
        headers: {
            'Content-Type': 'application/json',
            'Authorization': Auth.token ? `Bearer ${Auth.token}` : ''
        }
    };
    
    if (data) {
        options.body = JSON.stringify(data);
    }
    
    const response = await fetch(`${API_BASE_URL}/${endpoint}`, options);
    
    if (response.status === 401) {
        Auth.clearToken();
        throw new Error('登录已过期，请重新登录');
    }
    
    if (!response.ok) {
        throw new Error(`HTTP错误: ${response.status}`);
    }
    
    return await response.json();
}

// 页面显示控制
function showAuth(page = 'login') {
    const authContainer = document.getElementById('auth-container');
    const appContainer = document.getElementById('app-container');
    
    if (!authContainer || !appContainer) {
        console.error('页面容器元素未找到');
        return;
    }
    
    appContainer.style.display = 'none';
    authContainer.style.display = 'flex';
    loadAuthPage(page);
}

function showApp() {
    const authContainer = document.getElementById('auth-container');
    const appContainer = document.getElementById('app-container');
    
    if (!authContainer || !appContainer) {
        console.error('页面容器元素未找到');
        return;
    }
    
    authContainer.style.display = 'none';
    appContainer.style.display = 'flex';
    initApp();
}

// 修改为全局可访问的函数
window.loadAuthPage = function(page) {
    const authContent = document.getElementById('auth-content');
    if (!authContent) {
        console.error('认证内容容器未找到');
        return;
    }

    authContent.innerHTML = `
        <div style="text-align: center; padding: 30px;">
            <div class="spinner"></div>
        </div>
    `;

    fetch(`/views/auth/${page}.html`)
        .then(res => {
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            return res.text();
        })
        .then(html => {
            authContent.innerHTML = html;
            AuthManager.initAuthPage(page);
        })
        .catch(err => {
            console.error('加载认证页面失败:', err);
            authContent.innerHTML = `
                <div class="error-message">
                    页面加载失败: ${err.message}<br>
                    <button onclick="loadAuthPage('login')" class="btn">返回登录</button>
                </div>
            `;
        });
};

// 加载子页面
async function loadSubpage(pageName) {
    try {
        const content = document.getElementById('content');
        content.innerHTML = `
            <div class="loading" style="text-align: center; padding: 50px;">
                <div style="font-size: 1.2rem; margin-bottom: 20px;">加载中...</div>
                <div class="spinner"></div>
            </div>
        `;
        
        // 更新菜单激活状态
        document.querySelectorAll('.menu-item').forEach(item => {
            item.classList.remove('active');
            if (item.dataset.page === pageName) {
                item.classList.add('active');
            }
        });
        
        const response = await fetch(`/views/admin/${pageName}.html`);
        if (!response.ok) throw new Error('页面加载失败');
        
        content.innerHTML = await response.text();
        
        // 初始化页面脚本
        if (pageName === 'online') initOnlinePage();
        else if (pageName === 'server') initServerPage();
        else if (pageName === 'profile') initProfilePage();
        else if (pageName === 'config') initConfigPage();
        
    } catch (err) {
        console.error(err);
        document.getElementById('content').innerHTML = `
            <div class="error" style="text-align: center; padding: 50px; color: #e74c3c;">
                <h3>页面加载失败</h3>
                <p>${err.message}</p>
                <button onclick="location.reload()" class="btn" style="margin-top: 20px;">重试</button>
            </div>
        `;
    }
}

// 初始化应用
function initApp() {
    // 初始化菜单点击事件
    document.querySelectorAll('.menu-item[data-page]').forEach(link => {
        link.addEventListener('click', (e) => {
            if (e.currentTarget.dataset.page === 'login') {
                e.preventDefault();
                showAuth('login');
                return;
            }
            
            e.preventDefault();
            loadSubpage(e.currentTarget.dataset.page);
        });
    });
    
    // 退出登录按钮
    document.getElementById('logout-btn')?.addEventListener('click', (e) => {
        e.preventDefault();
            Auth.showModal('确认退出', '您确定要退出登录吗？', [
                {
                    text: '取消',
                    action: 'Auth.hideModal()'
                },
                {
                    text: '确定退出',
                    primary: true,
                    action: 'Auth.clearToken()'
                }
            ], true);

    });
    
    // 加载默认页面
    const firstMenuItem = document.querySelector('.menu-item');
    if (firstMenuItem) {
        loadSubpage(firstMenuItem.dataset.page);
    }
    
    Auth.init();
}

// 启动应用
document.addEventListener('DOMContentLoaded', () => {
    const token = Auth.getTokenFromCookie();
    if (token) {
        Auth.token = token;
        showApp();
    } else {
        showAuth();
    }
});

// // 子页面初始化函数 (示例)
// function initOnlinePage() {
//     console.log('初始化在线玩家页面');
//     // 实际初始化代码...
// }

// function initServerPage() {
//     console.log('初始化服务器状态页面');
//     // 实际初始化代码...
// }

// function initProfilePage() {
//     console.log('初始化个人中心页面');
//     // 实际初始化代码...
// }

// 在线玩家页面初始化
async function initOnlinePage() {
    console.log('初始化在线玩家页面');
    const refreshBtn = document.getElementById('refresh-online');
    const tbody = document.getElementById('online-data');
    
    if (!refreshBtn || !tbody) return;
    
    async function loadData() {
        try {
            const data = await fetchAPI('online');
            renderOnlineData(data);
        } catch (error) {
            console.error('获取在线玩家数据失败:', error);
            alert('获取数据失败: ' + error.message);
        }
    }
    
    function renderOnlineData(data) {
        tbody.innerHTML = '';
        // console.log(data)
        if (data.length == null || data.length === 0) {
            return
        }
        data.forEach(server => {
            if (server.online_count > 0){
                const row = document.createElement('tr');
                
                let statusClass = '';
                let statusText = '';
                
                if (server.online_count > 200) {
                    statusClass = 'status-high';
                    statusText = '高负载';
                } else if (server.online_count > 100) {
                    statusClass = 'status-medium';
                    statusText = '中负载';
                } else if (server.online_count >= 0) {
                    statusClass = 'status-low';
                    statusText = '低负载';
                } else {
                    statusClass = 'status-offline';
                    statusText = '离线';
                }
                
                row.innerHTML = `
                    <td>${server.server_name}</td>
                    <td>${server.game_name}</td>
                    <td>${server.online_count}</td>
                    <td class="${statusClass}">${statusText}</td>
                `;
                
                tbody.appendChild(row);
            }
        });
    }
    
    refreshBtn.addEventListener('click', async () => {
        refreshBtn.textContent = '刷新中...';
        refreshBtn.disabled = true;
        await loadData();
        await load_online_history_data();
        refreshBtn.textContent = '刷新数据';
        refreshBtn.disabled = false;
    });
    async function load_online_history_data() {
        try {
            const data = await fetchAPI('online-history');
            // 加载online.js中的图表代码
            window.init_online_info_Chart(data);
        } catch (error) {
            console.error('获取历史在线玩家数据失败:', error);
            alert('获取数据失败: ' + error.message);
        }
    }
    
    await loadData();
    await load_online_history_data();
    
    
}


// 服务器状态页面初始化
async function initServerPage() {
    console.log('初始化服务器状态页面');
    const tbody = document.getElementById('server-data');
    const updateTime = document.getElementById('update-time');
    
    if (!tbody || !updateTime) return;
    
    async function loadData() {
        try {
            const data = await fetchAPI('server-status');
            renderServerData(data);
        } catch (error) {
            console.error('获取服务器状态失败:', error);
            alert('获取数据失败: ' + error.message);
        }
    }
    
    function renderServerData(data) {
        tbody.innerHTML = '';
        if (data.length == null || data.length === 0) {
            return
        }
        data.forEach(server => {
            const row = document.createElement('tr');
            
            const statusClass = server.status === 'online' ? 'status-online' : 'status-offline';
            const statusText = server.status === 'online' ? '在线' : '离线';
            
            row.innerHTML = `
                <td>${server.server_name}</td>
                <td class="${statusClass}">${statusText}</td>
                <td>${server.start_time || 'N/A'}</td>
                <td>
                    <div class="progress-bar">
                        <div class="progress" style="width: ${server.cpu || '0%'}"></div>
                        <span>${server.cpu || '0%'}</span>
                    </div>
                </td>
                <td>
                    <div class="progress-bar">
                        <div class="progress" style="width: ${server.memory || '0%'}"></div>
                        <span>${server.memory || '0%'}</span>
                    </div>
                </td>
            `;
            
            tbody.appendChild(row);
        });
        
        updateTime.textContent = new Date().toLocaleTimeString();
    }
    
    await loadData();
    // setInterval(loadData, 30000);
}

// 参数配置页面初始化
async function initConfigPage() {
     // 表单提交处理
     console.log("初始化参数配置页面")
     document.getElementById('config-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const paramName = document.getElementById('param-name').value;
        const paramValue = document.getElementById('param-value').value;
        
        if (!paramName || !paramValue) {
            alert('请填写完整的参数信息');
            return;
        }
        
        const submitBtn = e.target.querySelector('button[type="submit"]');
        submitBtn.disabled = true;
        submitBtn.textContent = '提交中...';
        
        try {
            // 调用API提交数据
            const response = await parent.fetchAPI('config', 'POST', {
                parameter: paramName,
                value: paramValue
            });
            
            // 显示响应
            const responseArea = document.getElementById('response-area');
            const responseContent = document.getElementById('response-content');
            
            responseContent.textContent = JSON.stringify(response, null, 2);
            responseArea.style.display = 'block';
            
            // 重置表单
            document.getElementById('config-form').reset();
            
            // 显示成功提示
            alert('参数修改成功!');
        } catch (error) {
            console.error('请求失败:', error);
            alert('参数修改失败: ' + error.message);
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = '提交修改';
        }
    });
}
// 个人中心页面初始化
function initProfilePage() {
    console.log('初始化个人中心页面');
    
    // 确保用户已登录
    if (!Auth.token) {
        loadSubpage('login');
        return;
    }

    // 立即显示用户名（如果已有）
    const profileUsername = document.getElementById('profile-username');
    if (profileUsername && Auth.username) {
        profileUsername.textContent = Auth.username;
    }

    // 修改手机号按钮 - 分两步验证
    const changePhoneBtn = document.getElementById('change-phone-btn');
    if (changePhoneBtn) {
        changePhoneBtn.addEventListener('click', () => {
            // 第一步：验证旧手机号
            Auth.showModal('验证旧手机号', `
                <div style="text-align: center; margin-bottom: 20px; color: #666;">
                    <p>为了您的账户安全，需要先验证当前手机号</p>
                </div>
                <div class="form-group">
                    <label class="form-label">当前手机号</label>
                    <input type="text" id="old-phone" class="form-input" placeholder="请输入当前手机号" required>
                </div>
                <div class="form-group">
                    <label class="form-label">验证码</label>
                    <div style="display: flex; gap: 10px;">
                        <input type="text" id="old-phone-code" class="form-input" style="flex: 1;" placeholder="请输入验证码" required>
                        <button type="button" onclick="sendOldPhoneCode()" id="send-old-phone-code-btn" class="btn" style="width: 120px;">发送验证码</button>
                    </div>
                </div>
            `, [
                {
                    text: '取消',
                    action: 'Auth.hideModal()'
                },
                {
                    text: '验证',
                    primary: true,
                    action: `
                        const oldPhone = document.getElementById('old-phone').value;
                        const oldCode = document.getElementById('old-phone-code').value;
                        
                        if (!oldPhone || !oldCode) {
                            alert('请填写完整信息');
                            return;
                        }
                        
                        // 验证旧手机号
                        fetchAPI('verify-old-phone', 'POST', { 
                            oldPhone: oldPhone, 
                            code: oldCode 
                        })
                            .then(() => {
                                // 验证成功后，显示第二步：填写新手机号
                                showNewPhoneModal();
                            })
                            .catch(err => alert('验证失败: ' + err.message));
                    `
                }
            ], true);
        });
    }

    // 修改密码按钮 - 增加手机号验证
    const changePasswordBtn = document.getElementById('change-password-btn');
    if (changePasswordBtn) {
        changePasswordBtn.addEventListener('click', () => {
            Auth.showModal('修改密码', `
                <div style="text-align: center; margin-bottom: 20px; color: #666;">
                    <p>为了您的账户安全，需要通过手机号验证</p>
                </div>
                <div class="form-group">
                    <label class="form-label">手机号</label>
                    <input type="text" id="password-phone" class="form-input" placeholder="请输入手机号" required>
                </div>
                <div class="form-group">
                    <label class="form-label">验证码</label>
                    <div style="display: flex; gap: 10px;">
                        <input type="text" id="password-code" class="form-input" style="flex: 1;" placeholder="请输入验证码" required>
                        <button type="button" onclick="sendPasswordCode()" id="send-password-code-btn" class="btn" style="width: 120px;">发送验证码</button>
                    </div>
                </div>
                <div class="form-group">
                    <label class="form-label">新密码</label>
                    <input type="password" id="new-password" class="form-input" placeholder="请输入新密码" required>
                </div>
                <div class="form-group">
                    <label class="form-label">确认新密码</label>
                    <input type="password" id="confirm-new-password" class="form-input" placeholder="请再次输入新密码" required>
                </div>
            `, [
                {
                    text: '取消',
                    action: 'Auth.hideModal()'
                },
                {
                    text: '确认修改',
                    primary: true,
                    action: `
                        const phone = document.getElementById('password-phone').value;
                        const code = document.getElementById('password-code').value;
                        const newPassword = document.getElementById('new-password').value;
                        const confirmPassword = document.getElementById('confirm-new-password').value;
                        
                        if (!phone || !code || !newPassword || !confirmPassword) {
                            alert('请填写完整信息');
                            return;
                        }
                        
                        if (newPassword !== confirmPassword) {
                            alert('两次输入的新密码不一致');
                            return;
                        }
                        
                        // 先验证手机号，再修改密码
                        fetchAPI('verify-phone-for-password', 'POST', { 
                            phone: phone, 
                            code: code 
                        })
                            .then(() => {
                                // 验证成功后修改密码
                                return fetchAPI('change-password', 'POST', { 
                                    newPassword: newPassword 
                                });
                            })
                            .then(() => {
                                alert('密码修改成功');
                                Auth.hideModal();
                            })
                            .catch(err => alert('修改失败: ' + err.message));
                    `
                }
            ], true);
        });
    }

    // 个人中心的退出按钮 - 使用超紧凑模式
    const logoutProfileBtn = document.getElementById('logout-profile-btn');
    if (logoutProfileBtn) {
        logoutProfileBtn.addEventListener('click', (e) => {
            e.preventDefault();
            Auth.showModal('确认退出', '您确定要退出登录吗？', [
                {
                    text: '取消',
                    action: 'Auth.hideModal()'
                },
                {
                    text: '确定退出',
                    primary: true,
                    action: 'Auth.clearToken()'
                }
            ], true);
        });
    }

    // 全局函数供按钮调用
    window.showNewPhoneModal = function() {
        Auth.showModal('设置新手机号', `
            <div style="text-align: center; margin-bottom: 20px; color: #666;">
                <p>旧手机号验证成功，请输入新手机号</p>
            </div>
            <div class="form-group">
                <label class="form-label">新手机号</label>
                <input type="text" id="new-phone" class="form-input" placeholder="请输入新手机号" required>
            </div>
            <div class="form-group">
                <label class="form-label">验证码</label>
                <div style="display: flex; gap: 10px;">
                    <input type="text" id="new-phone-code" class="form-input" style="flex: 1;" placeholder="请输入验证码" required>
                    <button type="button" onclick="sendNewPhoneCode()" id="send-new-phone-code-btn" class="btn" style="width: 120px;">发送验证码</button>
                </div>
            </div>
        `, [
            {
                text: '取消',
                action: 'Auth.hideModal()'
            },
            {
                text: '确认修改',
                primary: true,
                action: `
                    const newPhone = document.getElementById('new-phone').value;
                    const newCode = document.getElementById('new-phone-code').value;
                    
                    if (!newPhone || !newCode) {
                        alert('请填写完整信息');
                        return;
                    }
                    
                    fetchAPI('change-phone', 'POST', { 
                        newPhone: newPhone, 
                        code: newCode 
                    })
                        .then(() => {
                            alert('手机号修改成功');
                            Auth.fetchUserInfo(); // 刷新用户信息
                            Auth.hideModal();
                        })
                        .catch(err => alert('修改失败: ' + err.message));
                `
            }
        ], true);
    };

    window.sendOldPhoneCode = function() {
        const oldPhone = document.getElementById('old-phone')?.value;
        const btn = document.getElementById('send-old-phone-code-btn');
        
        if (!oldPhone) {
            alert('请输入当前手机号');
            return;
        }
        
        fetchAPI('send-sms', 'POST', { phone: oldPhone, type: 'verify' })
            .then(() => {
                startCountdown(btn, 60);
                alert('验证码已发送到当前手机号');
            })
            .catch(err => alert('发送失败: ' + err.message));
    };

    window.sendNewPhoneCode = function() {
        const newPhone = document.getElementById('new-phone')?.value;
        const btn = document.getElementById('send-new-phone-code-btn');
        
        if (!newPhone) {
            alert('请输入新手机号');
            return;
        }
        
        fetchAPI('send-sms', 'POST', { phone: newPhone, type: 'new_phone' })
            .then(() => {
                startCountdown(btn, 60);
                alert('验证码已发送到新手机号');
            })
            .catch(err => alert('发送失败: ' + err.message));
    };

    window.sendPasswordCode = function() {
        const phone = document.getElementById('password-phone')?.value;
        const btn = document.getElementById('send-password-code-btn');
        
        if (!phone) {
            alert('请输入手机号');
            return;
        }
        
        fetchAPI('send-sms', 'POST', { phone: phone, type: 'change_password' })
            .then(() => {
                startCountdown(btn, 60);
                alert('验证码已发送');
            })
            .catch(err => alert('发送失败: ' + err.message));
    };

    // 倒计时函数
    function startCountdown(button, seconds) {
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
    }

    // 加载用户信息（如果还没有username）
    if (!Auth.username) {
        Auth.fetchUserInfo();
    }
}