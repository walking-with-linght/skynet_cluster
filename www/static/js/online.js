


var option;

option = {
	title: {
		text: '正式服'
	},
	tooltip: {
		trigger: 'axis'
	},
	legend: {
		data: ['crash', 'mines', 'dice', 'limbo', 'plinko']
	},
	grid: {
		left: '3%',
		right: '4%',
		bottom: '3%',
		containLabel: true
	},
	toolbox: {
		feature: {
			saveAsImage: {}
		}
	},
	xAxis: {
		type: 'category',
		boundaryGap: false,
		data: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
	},
	yAxis: {
		type: 'value'
	},
	series: [
		{
			name: 'Email',
			type: 'line',
			stack: 'Total',
			data: [120, 132, 101, 134, 90, 230, 210]
		},
		{
			name: 'Union Ads',
			type: 'line',
			stack: 'Total',
			data: [220, 182, 191, 234, 290, 330, 310]
		},
		{
			name: 'Video Ads',
			type: 'line',
			stack: 'Total',
			data: [150, 232, 201, 154, 190, 330, 410]
		},
		{
			name: 'Direct',
			type: 'line',
			stack: 'Total',
			data: [320, 332, 301, 334, 390, 330, 320]
		},
		{
			name: 'Search Engine',
			type: 'line',
			stack: 'Total',
			data: [820, 932, 901, 934, 1290, 1330, 1320]
		}
	]
};

const tmp_data = {
	myChart: null,
}

// 立即初始化图表（因为脚本是动态加载的）
window.init_online_info_Chart = function (data) {
	// console.log('开始初始化图表...');
	var chartDom = document.getElementById('online_history_container');
	const select = document.getElementById('online-history-select');
	select.innerHTML = '';
	if (data.options.length > 0) {
		data.options.forEach(opt => {
			const option = document.createElement('option');
			option.value = opt.value;
			option.textContent = opt.label;
			select.appendChild(option);
		});
	}

	// if (tmp_data.myChart == null){
	// 确保容器有正确的尺寸
	chartDom.style.width = '100%';
	chartDom.style.height = '400px';
	tmp_data.myChart = echarts.init(chartDom);
	// 响应式调整
	window.addEventListener('resize', function () {
		tmp_data.myChart.resize();
	});
	// }
	// 默认显示第一个
	if (data.options.length > 0) {
		tmp_data.myChart.setOption(data.data[data.options[0].value]);
	}
	select.onchange = function () {
		const val = select.value;
		tmp_data.myChart.setOption(data.data[val]);
	};


	console.log('图表初始化成功');
}

// // 新增：下拉框和图表联动逻辑
// window.initOnlineHistoryDropdown = async function() {
//     const select = document.getElementById('online-history-select');
//     if (!select) return;
//     try {
//         const data = await fetchAPI('online-history');
//         // 假设data.options为下拉项，data.charts为各项对应的图表数据
//         if (!data.options || !data.charts) return;
//         select.innerHTML = '';
//         data.options.forEach(opt => {
//             const option = document.createElement('option');
//             option.value = opt.value;
//             option.textContent = opt.label;
//             select.appendChild(option);
//         });
//         // 默认显示第一个
//         if (data.options.length > 0) {
//             window.init_online_info_Chart(data.charts[data.options[0].value]);
//         }
//         select.onchange = function() {
//             const val = select.value;
//             window.init_online_info_Chart(data.charts[val]);
//         };
//     } catch (e) {
//         console.error('下拉框初始化失败', e);
//     }
// };
// 页面加载后自动初始化
// window.addEventListener('DOMContentLoaded', function() {
//     window.initOnlineHistoryDropdown && window.initOnlineHistoryDropdown();
// });

// 延迟执行初始化，确保DOM完全准备好
// setTimeout(function() {
//     console.log('online.js脚本开始执行');
//     window.initChart();
// }, 100);