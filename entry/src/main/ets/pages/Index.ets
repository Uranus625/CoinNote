import { promptAction } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import BillRdb from '../db/BillRdb';
import { BillItem } from '../model/BillItem';

// 显式定义所有需要的样式接口
interface SelectOption {
  value: string;
  icon?: Resource;
}

// 统计数据接口
interface MonthlyStats {
  totalIncome: number;
  totalExpense: number;
  balance: number;
}

// 每日分组接口
interface DayGroup {
  date: string;
  dayIncome: number;
  dayExpense: number;
  bills: BillItem[];
}

// 饼图数据接口
interface PieData {
  category: string;
  amount: number;
  percentage: number;
  color: string;
}

// 每日趋势数据接口
interface DailyData {
  day: number;
  amount: number;
}

@Component
struct FormCard {
  @Prop title: string = "";
  @BuilderParam content: () => void = this.emptyBuilder;

  @Builder emptyBuilder() {}

  build() {
    Column() {
      Text(this.title)
        .fontSize(14)
        .fontColor("#666666")
        .margin({ bottom: 8 })
        .width("100%")
      
      Column() {
        this.content()
      }
      .width("100%")
      .backgroundColor(Color.White)
      .borderRadius(12)
      .padding(12)
      .shadow({ radius: 4, color: "#0D000000", offsetY: 2 }) // 柔和阴影
    }
    .width("100%")
    .margin({ bottom: 16 })
  }
}

@Entry
@Component
struct CoinNote {
  // 状态变量
  @State currentTab: number = 0;
  @State expenseType: string = "";
  @State amount: string = "";
  @State amountError: string = "";
  @State note: string = "";
  @State selectedDate: Date = new Date();
  @State dateStr: string = ""; // 初始化为空，在aboutToAppear中设置
  @State payType: string = "微信";
  @State tags: string[] = [];
  @State isReimbursable: boolean = false;
  @State billDirection: 'expense' | 'income' = 'expense'; // 修改：避免与系统属性冲突
  @State chartWidth: number = 300; // 图表宽度，默认300，通过onAreaChange更新
  @State chartHeight: number = 150; // 图表高度
  @State statsDate: Date = new Date(); // 统计页面的选中日期
  @State statsType: 'expense' | 'income' = 'expense'; // 统计类型
  @State searchText: string = ""; // 搜索关键字
  @State editingBillId: number = 0; // 正在编辑的账单ID，0表示新增模式
  
  // Canvas设置
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  
  // 柱状图 Canvas 设置
  private barSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private barContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.barSettings);

  // 动画相关
  @State chartProgress: number = 0; // 0.0 -> 1.0

  // 触发图表动画
  private animateCharts(): void {
    this.chartProgress = 0;
    let start = Date.now();
    const duration = 800; // 800ms 动画时长

    const step = (): void => {
      const now = Date.now();
      const progress = Math.min((now - start) / duration, 1);
      // 使用 EaseOutCubic 缓动函数让动画更自然: 1 - (1-x)^3
      this.chartProgress = 1 - Math.pow(1 - progress, 3);
      
      this.drawPieChart();
      this.drawBarChart();

      if (progress < 1) {
        setTimeout(step, 16); // 约 60fps
      }
    };
    step();
  }

  // 账单列表
  @State @Watch('onBillListChange') billList: BillItem[] = [];

  onBillListChange(): void {
    // 数据变化时触发动画重绘
    this.animateCharts();
  }

  aboutToAppear(): void {
    const now = new Date();
    this.dateStr = this.formatDate(now);
    
    // 初始化数据库并加载数据
    const context = getContext(this) as common.UIAbilityContext;
    BillRdb.getRdbStore(context).then(() => {
      this.refreshBillList();
    }).catch((err: Error) => {
      console.error('DB Init failed', err);
    });
  }

  // 刷新账单列表
  private refreshBillList(): void {
    BillRdb.queryAll().then((list) => {
      this.billList = list;
    });
  }

  // 日期格式化 YYYY/M/D
  private formatDate(date: Date): string {
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
  }

  // 选项数据
  private expenseTypes: string[] = ["餐饮", "交通", "购物", "娱乐", "水电煤", "房租", "通讯", "医疗", "其他"];
  private incomeTypes: string[] = ["工资", "奖金", "理财", "兼职", "礼金", "其他"]; // 新增：收入类型
  private payTypes: string[] = ["微信", "支付宝", "银行卡", "现金"];
  private tagOptions: string[] = ["早餐", "午餐", "晚餐", "外卖", "地铁", "公交", "超市", "电影", "通勤", "日用品", "聚餐"];

  // 生成Select选项
  private getSelectOptions(): SelectOption[] {
    const types = this.billDirection === 'expense' ? this.expenseTypes : this.incomeTypes;
    return types.map((type: string): SelectOption => ({ value: type }));
  }

  // 获取分类颜色
  private getCategoryColor(type: string): string {
    const colors: Record<string, string> = {
      "餐饮": "#FF9500", // 橙色
      "交通": "#007AFF", // 蓝色
      "购物": "#FF2D55", // 红色
      "娱乐": "#5856D6", // 紫色
      "水电煤": "#5AC8FA", // 浅蓝
      "房租": "#FFCC00", // 黄色
      "通讯": "#4CD964", // 绿色
      "医疗": "#FF3B30", // 红色
      "其他": "#8E8E93", // 灰色
      "工资": "#34C759", // 绿色
      "奖金": "#FFD60A", // 金色
      "理财": "#AF52DE", // 紫色
      "兼职": "#5AC8FA", // 浅蓝
      "礼金": "#FF2D55"  // 红色
    };
    return colors[type] || "#4A6CF7";
  }

  // 金额校验
  private validateAmount(): boolean {
    if (this.amount === "") {
      this.amountError = "金额不能为空";
      return false;
    } else if (isNaN(Number(this.amount)) || Number(this.amount) <= 0) {
      this.amountError = "请输入有效的正数金额";
      return false;
    } else {
      this.amountError = "";
      return true;
    }
  }

  // 添加或更新账单
  private addBill(): void {
    if (!this.validateAmount()) {
      promptAction.showToast({ message: '请检查金额输入', duration: 2000 });
      return;
    }
    if (this.expenseType === "") {
      promptAction.showToast({ message: '请选择分类', duration: 2000 });
      return;
    }

    const bill: BillItem = {
      id: this.editingBillId > 0 ? this.editingBillId : Date.now(),
      type: this.expenseType,
      amount: Number(this.amount),
      date: this.dateStr,
      payType: this.payType,
      tags: [...this.tags],
      isReimbursable: this.isReimbursable,
      note: this.note,
      direction: this.billDirection
    };

    // 定义操作
    const doSave = () => {
      if (this.editingBillId > 0) {
        // 更新
        BillRdb.update(bill).then(() => {
          promptAction.showToast({ message: '修改成功！', duration: 2000 });
          this.refreshBillList();
          this.resetForm();
        }).catch((err: Error) => {
          console.error('Update failed', err);
          promptAction.showToast({ message: '修改失败: ' + (err.message || JSON.stringify(err)), duration: 3000 });
        });
      } else {
        // 新增
        BillRdb.insert(bill).then(() => {
          promptAction.showToast({ message: '记账成功！', duration: 2000 });
          this.refreshBillList();
          this.resetForm();
        }).catch((err: Error) => {
          console.error('Insert failed', err);
          promptAction.showToast({ message: '记账失败: ' + (err.message || JSON.stringify(err)), duration: 3000 });
        });
      }
    };

    // 检查数据库是否初始化，如果没有则尝试重新初始化
    if (!BillRdb.isInitialized()) {
      const context = getContext(this) as common.UIAbilityContext;
      BillRdb.getRdbStore(context).then(() => {
        doSave();
      }).catch((err: Error) => {
        // 提取更详细的错误信息
        const errorMsg = JSON.stringify(err) !== '{}' ? JSON.stringify(err) : err.message;
        promptAction.showToast({ message: 'DB Init Error: ' + errorMsg, duration: 5000 });
        console.error('DB Init Error Detail:', errorMsg);
      });
    } else {
      doSave();
    }
  }

  private resetForm(): void {
    this.editingBillId = 0; // 重置编辑状态
    this.expenseType = "";
    this.amount = "";
    this.note = "";
    this.tags = [];
    this.selectedDate = new Date();
    this.dateStr = this.formatDate(this.selectedDate);
    this.payType = "微信";
    this.isReimbursable = false;
    this.amountError = "";
    // 不重置 billDirection，方便连续记账
  }

  // 开始编辑
  private startEdit(bill: BillItem): void {
    this.editingBillId = bill.id;
    this.billDirection = bill.direction;
    this.expenseType = bill.type;
    this.amount = bill.amount.toString();
    this.dateStr = bill.date;
    this.selectedDate = new Date(bill.date);
    this.payType = bill.payType;
    this.tags = [...bill.tags];
    this.isReimbursable = bill.isReimbursable;
    this.note = bill.note;
    
    this.currentTab = 0; // 切换到记账页
  }

  // 显示日期选择器
  private showDatePicker(): void {
    DatePickerDialog.show({
      start: new Date("2020-1-1"),
      end: new Date("2100-12-31"),
      selected: this.selectedDate,
      onAccept: (value: DatePickerResult) => {
        // value.month is 0-indexed
        const year = value.year;
        const month = value.month;
        const day = value.day;
        if (year !== undefined && month !== undefined && day !== undefined) {
           this.selectedDate = new Date(year, month, day);
           this.dateStr = this.formatDate(this.selectedDate);
        }
      }
    })
  }

  // 删除账单
  private deleteBill(id: number): void {
    // 弹窗确认
    AlertDialog.show({
      title: '确认删除',
      message: '确定要删除这条账单记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: () => {
          BillRdb.delete(id).then(() => {
            promptAction.showToast({ message: '已删除', duration: 2000 });
            this.refreshBillList();
          });
        }
      }
    })
  }

  // 侧滑删除按钮
  @Builder itemEnd(id: number) {
    Row() {
      Button("删除")
        .type(ButtonType.Normal)
        .width(80)
        .height("100%")
        .backgroundColor(Color.Red)
        .fontColor(Color.White)
        .onClick(() => {
          this.deleteBill(id);
        })
    }
    .padding({ left: 12 })
    .justifyContent(FlexAlign.End)
  }

  // 获取本月统计数据
  private getMonthlyStats(): MonthlyStats {
    const currentMonth = this.statsDate.getMonth();
    const currentYear = this.statsDate.getFullYear();
    
    let totalIncome = 0;
    let totalExpense = 0;
    
    this.billList.forEach(bill => {
      // 手动解析日期字符串 YYYY/M/D
      const parts = bill.date.split('/');
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const month = parseInt(parts[1]) - 1; // month is 0-indexed
        const day = parseInt(parts[2]);
        
        if (month === currentMonth && year === currentYear) {
          if (bill.direction === 'income') {
            totalIncome += bill.amount;
          } else {
            totalExpense += bill.amount;
          }
        }
      }
    });
    
    return { totalIncome, totalExpense, balance: totalIncome - totalExpense };
  }

  // 按日期分组账单
  private getGroupedBills(): DayGroup[] {
    const groups: Record<string, DayGroup> = {};
    const keyword = this.searchText.trim().toLowerCase();
    
    this.billList.forEach((bill: BillItem): void => {
      // 搜索过滤逻辑
      if (keyword) {
        const matchType = bill.type.toLowerCase().includes(keyword);
        const matchNote = bill.note.toLowerCase().includes(keyword);
        const matchAmount = bill.amount.toString().includes(keyword);
        const matchTags = bill.tags.some((tag: string): boolean => tag.toLowerCase().includes(keyword));
        // 如果是报销单，且关键字包含在"报销"中（例如搜"报"、"销"或"报销"），则匹配
        const matchReimbursable = bill.isReimbursable && '报销'.includes(keyword);
        
        if (!matchType && !matchNote && !matchAmount && !matchTags && !matchReimbursable) {
          return; // 如果都不匹配，跳过该条目
        }
      }

      if (!groups[bill.date]) {
        groups[bill.date] = {
          date: bill.date,
          dayIncome: 0,
          dayExpense: 0,
          bills: []
        };
      }
      
      const group = groups[bill.date];
      group.bills.push(bill);
      if (bill.direction === 'income') {
        group.dayIncome += bill.amount;
      } else {
        group.dayExpense += bill.amount;
      }
    });
    
    // 转换为数组并按日期倒序排序
    return Object.values(groups).sort((a: DayGroup, b: DayGroup): number => {
      return new Date(b.date).getTime() - new Date(a.date).getTime();
    });
  }

  // 分组头部组件
  @Builder groupHeader(group: DayGroup) {
    Row() {
      Text(group.date)
        .fontSize(14)
        .fontColor("#666666")
        .fontWeight(FontWeight.Bold)
      
      Blank()
      
      Row() {
        if (group.dayIncome > 0) {
          Text(`收 ${group.dayIncome.toFixed(2)}`)
            .fontSize(12)
            .fontColor("#999999")
            .margin({ right: 12 })
        }
        
        if (group.dayExpense > 0) {
          Text(`支 ${group.dayExpense.toFixed(2)}`)
            .fontSize(12)
            .fontColor("#999999")
        }
      }
    }
    .width("100%")
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .backgroundColor("#F9FAFB") 
  }

  // 显示统计日期选择器
  private showStatsDatePicker(): void {
    DatePickerDialog.show({
      start: new Date("2020-1-1"),
      end: new Date("2100-12-31"),
      selected: this.statsDate,
      onAccept: (value: DatePickerResult) => {
        const year = value.year;
        const month = value.month;
        if (year !== undefined && month !== undefined) {
           // 只需要年月，日设为1
           this.statsDate = new Date(year, month, 1);
           // 日期改变后重绘
           setTimeout((): void => { 
             this.animateCharts();
           }, 100);
        }
      }
    })
  }

  // 获取饼图数据
  private getPieData(): PieData[] {
    const currentMonth = this.statsDate.getMonth();
    const currentYear = this.statsDate.getFullYear();
    const typeMap: Record<string, number> = {};
    let total = 0;

    this.billList.forEach((bill: BillItem): void => {
      const parts = bill.date.split('/');
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const month = parseInt(parts[1]) - 1;
        
        if (month === currentMonth && year === currentYear && bill.direction === this.statsType) {
          if (!typeMap[bill.type]) {
            typeMap[bill.type] = 0;
          }
          typeMap[bill.type] += bill.amount;
          total += bill.amount;
        }
      }
    });

    if (total === 0) return [];

    const result: PieData[] = Object.keys(typeMap).map((type: string): PieData => {
      return {
        category: type,
        amount: typeMap[type],
        percentage: typeMap[type] / total,
        color: this.getCategoryColor(type)
      } as PieData;
    });

    // 按金额降序排序
    return result.sort((a: PieData, b: PieData): number => b.amount - a.amount);
  }

  // 绘制饼图
  private drawPieChart(): void {
    // 确保context已初始化
    if (!this.context) return;
    
    const width = this.context.width;
    const height = this.context.height;
    const radius = Math.min(width, height) / 2 * 0.8;
    const centerX = width / 2;
    const centerY = height / 2;

    this.context.clearRect(0, 0, width, height);

    const data = this.getPieData();
    if (data.length === 0) {
      // 空状态绘制
      this.context.beginPath();
      this.context.arc(centerX, centerY, radius, 0, 2 * Math.PI);
      this.context.fillStyle = '#F0F2F5';
      this.context.fill();
      
      this.context.fillStyle = '#999999';
      this.context.font = '14vp sans-serif';
      this.context.textAlign = 'center';
      this.context.textBaseline = 'middle';
      this.context.fillText('暂无数据', centerX, centerY);
      return;
    }

    let startAngle = -0.5 * Math.PI; // 从12点钟方向开始

    data.forEach((item: PieData): void => {
      // 动画：根据进度计算当前扇区的扫描角度
      const sliceAngle = item.percentage * 2 * Math.PI * this.chartProgress;
      const endAngle = startAngle + sliceAngle;

      this.context.beginPath();
      this.context.moveTo(centerX, centerY);
      this.context.arc(centerX, centerY, radius, startAngle, endAngle);
      this.context.closePath();
      this.context.fillStyle = item.color;
      this.context.fill();

      // 绘制白色分割线 (仅当有进度时显示)
      if (this.chartProgress > 0.1) {
        this.context.beginPath();
        this.context.moveTo(centerX, centerY);
        this.context.arc(centerX, centerY, radius, startAngle, endAngle);
        this.context.strokeStyle = '#FFFFFF';
        this.context.lineWidth = 2;
        this.context.stroke();
      }

      startAngle = endAngle;
    });
    
    // 绘制中间的白色圆圈，形成甜甜圈效果
    this.context.beginPath();
    this.context.arc(centerX, centerY, radius * 0.6, 0, 2 * Math.PI);
    this.context.fillStyle = '#FFFFFF';
    this.context.fill();
    
    // 中间显示总金额 (带透明度动画)
    const total = data.reduce((sum: number, item: PieData): number => sum + item.amount, 0);
    
    // 简单的淡入效果
    this.context.globalAlpha = this.chartProgress; 
    
    this.context.fillStyle = '#333333';
    this.context.font = 'bold 16vp sans-serif';
    this.context.textAlign = 'center';
    this.context.textBaseline = 'middle';
    this.context.fillText(this.statsType === 'expense' ? '总支出' : '总收入', centerX, centerY - 10);
    
    this.context.fillStyle = this.statsType === 'expense' ? '#333333' : '#34C759';
    this.context.font = 'bold 18vp sans-serif';
    // 数字滚动效果
    this.context.fillText((total * this.chartProgress).toFixed(2), centerX, centerY + 15);
    
    this.context.globalAlpha = 1.0; // 恢复透明度
  }

  // 获取每日趋势数据
  private getDailyData(): DailyData[] {
    const currentYear = this.statsDate.getFullYear();
    const currentMonth = this.statsDate.getMonth();
    // 获取当月天数
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    
    const dailyAmounts: number[] = new Array(daysInMonth).fill(0);

    this.billList.forEach((bill: BillItem): void => {
      const parts = bill.date.split('/');
      if (parts.length === 3) {
        const year = parseInt(parts[0]);
        const month = parseInt(parts[1]) - 1;
        const day = parseInt(parts[2]);
        
        if (month === currentMonth && year === currentYear && bill.direction === this.statsType) {
          if (day >= 1 && day <= daysInMonth) {
            dailyAmounts[day - 1] += bill.amount;
          }
        }
      }
    });

    return dailyAmounts.map((amount: number, index: number): DailyData => ({ day: index + 1, amount }));
  }

  // 绘制柱状图
  private drawBarChart(): void {
    if (!this.barContext) return;

    const width = this.barContext.width;
    const height = this.barContext.height;
    const padding = 20;
    const bottomPadding = 30;
    const topPadding = 20;
    
    this.barContext.clearRect(0, 0, width, height);

    const data = this.getDailyData();
    const maxAmount = Math.max(...data.map((d: DailyData): number => d.amount));
    
    if (maxAmount === 0) {
      this.barContext.fillStyle = '#999999';
      this.barContext.font = '14vp sans-serif';
      this.barContext.textAlign = 'center';
      this.barContext.textBaseline = 'middle';
      this.barContext.fillText('暂无趋势数据', width / 2, height / 2);
      return;
    }

    const chartWidth = width - padding * 2;
    const chartHeight = height - topPadding - bottomPadding;
    const barWidth = (chartWidth / data.length) * 0.6;
    const spacing = (chartWidth / data.length) * 0.4;
    
    // 绘制坐标轴线
    this.barContext.beginPath();
    this.barContext.moveTo(padding, height - bottomPadding);
    this.barContext.lineTo(width - padding, height - bottomPadding);
    this.barContext.strokeStyle = '#E0E0E0';
    this.barContext.lineWidth = 1;
    this.barContext.stroke();

    data.forEach((item: DailyData, index: number): void => {
      const x = padding + index * (barWidth + spacing) + spacing / 2;
      // 动画：高度随进度变化
      const barHeight = (item.amount / maxAmount) * chartHeight * this.chartProgress;
      const y = height - bottomPadding - barHeight;

      // 绘制柱子
      this.barContext.fillStyle = this.statsType === 'expense' ? '#4A6CF7' : '#34C759';
      // 圆角矩形效果模拟（顶部圆角）
      this.barContext.beginPath();
      this.barContext.rect(x, y, barWidth, barHeight);
      this.barContext.fill();

      // 绘制日期标签（每隔5天显示一次，或者是第一天和最后一天）
      // 优化：如果5的倍数距离最后一天太近（<2天），则不显示，避免与最后一天重叠
      const isFirst = item.day === 1;
      const isLast = item.day === data.length;
      const isMultipleOfFive = item.day % 5 === 0;
      const isSafeMultiple = isMultipleOfFive && (data.length - item.day > 1);

      // 标签也添加淡入动画
      if ((isFirst || isLast || isSafeMultiple) && this.chartProgress > 0.5) {
        this.barContext.globalAlpha = (this.chartProgress - 0.5) * 2;
        this.barContext.fillStyle = '#999999';
        this.barContext.font = '10vp sans-serif';
        this.barContext.textAlign = 'center';
        this.barContext.textBaseline = 'top';
        this.barContext.fillText(item.day.toString(), x + barWidth / 2, height - bottomPadding + 4);
        this.barContext.globalAlpha = 1.0;
      }
    });
  }

  // 自定义 TabBar 构建器
  @Builder TabBuilder(title: string, index: number, icon: string) {
    Column() {
      Text(icon)
        .fontSize(22)
        .margin({ bottom: 4 })
        .opacity(this.currentTab === index ? 1 : 0.5)
        .animation({ duration: 300 }) // 添加简单的透明度动画
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTab === index ? "#4A6CF7" : "#999999")
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .animation({ duration: 300 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        // Logo
        Image($r('app.media.logo')) 
          .width(24)
          .height(24)
          .margin({ right: 8 })
          
        Text("CoinNote")
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width("100%")
      .height(44)
      .linearGradient({
        angle: 90,
        colors: [[0x4A6CF7, 0.0], [0x4E54C8, 1.0]]
      })
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center) 

      // 底部标签页
      Tabs({ index: this.currentTab, barPosition: BarPosition.End }) {
        // 标签页1：新增记账
        TabContent() {
          Scroll() {
            Column() {
              // 0. 收支切换
              Row() {
                Button("支出")
                  .type(ButtonType.Normal)
                  .backgroundColor(this.billDirection === 'expense' ? "#4A6CF7" : "#F0F2F5")
                  .fontColor(this.billDirection === 'expense' ? Color.White : "#666666")
                  .borderRadius({ topLeft: 8, bottomLeft: 8 })
                  .width("50%")
                  .height(36)
                  .onClick(() => {
                    this.billDirection = 'expense';
                    this.expenseType = ""; // 切换时重置分类
                  })
                
                Button("收入")
                  .type(ButtonType.Normal)
                  .backgroundColor(this.billDirection === 'income' ? "#34C759" : "#F0F2F5")
                  .fontColor(this.billDirection === 'income' ? Color.White : "#666666")
                  .borderRadius({ topRight: 8, bottomRight: 8 })
                  .width("50%")
                  .height(36)
                  .onClick(() => {
                    this.billDirection = 'income';
                    this.expenseType = ""; // 切换时重置分类
                  })
              }
              .width("100%")
              .margin({ bottom: 16 })

              // 1. 消费类型（下拉菜单）
              FormCard({ title: this.billDirection === 'expense' ? "消费类型 *" : "收入类型 *" }) {
                Select(this.getSelectOptions())
                  .value(this.expenseType || "请选择分类")
                  .font({ size: 16 })
                  .fontColor(this.expenseType ? "#333333" : "#999999")
                  .selectedOptionFont({ size: 16 })
                  .optionFont({ size: 16 })
                  .width("100%")
                  .height(48)
                  .onSelect((index: number, value: string) => {
                    this.expenseType = value;
                  })
              }

              // 2. 金额输入（文本输入 + 校验）
              FormCard({ title: "金额（元）*" }) {
                Column() {
                  TextInput({ placeholder: "0.00", text: this.amount })
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor("#F53F3F")
                    .width("100%")
                    .height(48)
                    .backgroundColor(Color.Transparent)
                    .type(InputType.Number) // 修正为 type
                    .onChange((value: string) => {
                      this.amount = value;
                      this.validateAmount();
                    })
                  
                  if (this.amountError) {
                    Text(this.amountError)
                      .fontSize(12)
                      .fontColor("#F53F3F")
                      .margin({ top: 4 })
                  }
                }
              }

              // 3. 日期选择（日期选择器）
              FormCard({ title: "日期" }) {
                Row() {
                  Text(this.dateStr)
                    .fontSize(16)
                    .fontColor("#333333")
                  Blank()
                  // 使用Text代替Image作为图标，因为没有资源
                  Text("📅") 
                    .fontSize(20)
                }
                .width("100%")
                .height(40)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.showDatePicker();
                })
              }

              // 4. 支付方式（单选 Radio）
              FormCard({ title: "支付方式" }) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.payTypes, (type: string) => {
                    Row() {
                      Radio({ value: type, group: "payType" })
                        .checked(this.payType === type)
                        .onChange((isChecked: boolean) => {
                          if (isChecked) {
                            this.payType = type;
                          }
                        })
                      Text(type)
                        .fontSize(14)
                        .fontColor("#333333")
                        .onClick(() => {
                           this.payType = type;
                        })
                    }
                    .margin({ right: 16, bottom: 8 })
                  })
                }
              }

              // 5. 标签（多选 Checkbox）
              FormCard({ title: "标签" }) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.tagOptions, (tag: string) => {
                    Row() {
                      Checkbox({ name: tag, group: "tags" })
                        .select(this.tags.includes(tag))
                        .onChange((isChecked: boolean) => {
                          if (isChecked) {
                            this.tags.push(tag);
                          } else {
                            this.tags = this.tags.filter(t => t !== tag);
                          }
                        })
                      Text(tag)
                        .fontSize(14)
                        .fontColor("#333333")
                        .onClick(() => {
                          // 简单的点击文字也能切换选中状态逻辑比较复杂，这里简化
                        })
                    }
                    .margin({ right: 12, bottom: 8 })
                  })
                }
              }

              // 6. 是否报销（Switch 开关）
              FormCard({ title: "其他选项" }) {
                Row() {
                  Text("是否报销")
                    .fontSize(16)
                    .fontColor("#333333")
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.isReimbursable })
                    .onChange((isOn: boolean) => {
                      this.isReimbursable = isOn;
                    })
                }
                .width("100%")
                .height(40)
                .alignItems(VerticalAlign.Center)
              }

              // 7. 备注（多行文本输入）
              FormCard({ title: "备注" }) {
                TextArea({ placeholder: "写点什么...", text: this.note })
                  .fontSize(14)
                  .width("100%")
                  .height(80)
                  .backgroundColor("#F5F7FA")
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.note = value;
                  })
              }

              // 提交按钮
              Button(this.editingBillId > 0 ? "保存修改" : "记一笔")
                .width("100%")
                .height(50)
                .linearGradient({
                  angle: 90,
                  colors: [[0x4A6CF7, 0.0], [0x4E54C8, 1.0]]
                })
                .fontColor(Color.White)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .borderRadius(25)
                .shadow({ radius: 8, color: "#4D4A6CF7", offsetY: 4 })
                .onClick(() => this.addBill())
                .margin({ top: 16, bottom: this.editingBillId > 0 ? 16 : 32 })

              if (this.editingBillId > 0) {
                Button("取消修改")
                  .width("100%")
                  .height(50)
                  .backgroundColor("#F0F2F5")
                  .fontColor("#666666")
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .borderRadius(25)
                  .onClick(() => this.resetForm())
                  .margin({ bottom: 32 })
              }
            }
            .padding(16)
          }
          .width("100%")
          .height("100%")
          .backgroundColor("#F9FAFB")
        }
        .tabBar(this.TabBuilder("记账", 0, "🖊️"))

        // 标签页2：明细列表
        TabContent() {
          Column() {
            // 搜索栏
            Row() {
              Search({ value: this.searchText, placeholder: '搜索分类、备注、金额或标签' })
                .width('100%')
                .height(40)
                .backgroundColor(Color.White)
                .placeholderColor('#999999')
                .placeholderFont({ size: 14 })
                .textFont({ size: 14 })
                .onChange((value: string) => {
                  this.searchText = value;
                })
            }
            .width("100%")
            .padding({ left: 16, right: 16, top: 12, bottom: 8 })

            if (this.billList.length === 0) {
              // 空状态
              Column() {
                // 使用Text代替Image作为空状态图标
                Text("📝")
                  .fontSize(60)
                  .margin({ bottom: 16 })
                Text("还没有账单哦，快去记一笔吧")
                  .fontSize(14)
                  .fontColor("#999999")
              }
              .width("100%")
              .height("60%")
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              // 账单列表（分组显示）
              List({ space: 0 }) {
                ForEach(this.getGroupedBills(), (group: DayGroup) => {
                  ListItemGroup({ header: this.groupHeader(group) }) {
                    ForEach(group.bills, (bill: BillItem) => {
                      ListItem() {
                        Row() {
                          // 左侧：图标或类型首字
                          Column() {
                            Text(bill.type.substring(0, 1))
                              .fontSize(18)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(Color.White)
                          }
                          .width(40)
                          .height(40)
                          .borderRadius(20)
                          .backgroundColor(this.getCategoryColor(bill.type))
                          .justifyContent(FlexAlign.Center)
                          .alignItems(HorizontalAlign.Center)
                          .margin({ right: 12 })

                          // 中间：信息
                          Column({ space: 4 }) {
                            Row({ space: 8 }) {
                              Text(bill.type)
                                .fontSize(16)
                                .fontWeight(FontWeight.Medium)
                                .fontColor("#333333")
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                                .layoutWeight(1)
                              if (bill.isReimbursable) {
                                Text("报销")
                                  .fontSize(10)
                                  .fontColor("#4A6CF7")
                                  .backgroundColor("#E6EAFB")
                                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                                  .borderRadius(4)
                                  .flexShrink(0)
                              }
                            }
                            .width("100%")
                            
                            Text(`${bill.date} · ${bill.payType}`)
                              .fontSize(12)
                              .fontColor("#999999")
                              .width("100%")
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                            
                            if (bill.note) {
                              Text(bill.note)
                                .fontSize(12)
                                .fontColor("#666666")
                                .width("100%")
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                                .margin({ top: 4 })
                            }
                          }
                          .layoutWeight(1)

                          // 右侧：金额
                          Column({ space: 4 }) {
                            Text(`${bill.direction === 'expense' ? '-' : '+'} ${bill.amount.toFixed(2)}`)
                              .fontSize(18)
                              .fontWeight(FontWeight.Bold)
                              .fontColor(bill.direction === 'expense' ? "#333333" : "#34C759")
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                            
                            if (bill.tags.length > 0) {
                              Text(bill.tags.join(" "))
                                .fontSize(12)
                                .fontColor("#999999")
                                .maxLines(1)
                                .textOverflow({ overflow: TextOverflow.Ellipsis })
                            }
                          }
                          .alignItems(HorizontalAlign.End)
                          .flexShrink(0)
                          .constraintSize({ maxWidth: "40%" })
                        }
                        .width("100%")
                        .padding(16)
                        .backgroundColor(Color.White)
                        .borderRadius(12)
                        .shadow({ radius: 4, color: "#0D000000", offsetY: 2 }) // 优化阴影
                        .onClick(() => {
                          ActionSheet.show({
                            title: '账单操作',
                            message: `类型：${bill.type}  金额：${bill.amount.toFixed(2)}`,
                            autoCancel: true,
                            alignment: DialogAlignment.Bottom,
                            offset: { dx: 0, dy: -10 },
                            sheets: [
                              {
                                title: '编辑',
                                action: () => {
                                  this.startEdit(bill);
                                }
                              },
                              {
                                title: '删除',
                                action: () => {
                                  this.deleteBill(bill.id);
                                }
                              }
                            ]
                          })
                        })
                      }
                      .swipeAction({ end: this.itemEnd(bill.id) })
                      .margin({ bottom: 12 })
                    })
                  }
                })
              }
              .width("100%")
              .layoutWeight(1)
              .padding({ left: 16, right: 16, bottom: 16 })
              .scrollBar(BarState.Auto) // 显示滚动条
              .sticky(StickyStyle.Header)
            }
          }
          .width("100%")
          .height("100%")
          .backgroundColor("#F9FAFB")
        }
        .tabBar(this.TabBuilder("明细", 1, "📄"))

        // 标签页3：统计
        TabContent() {
          Column() {
            // 头部：日期选择
            Row() {
              Text(`${this.statsDate.getFullYear()}年${this.statsDate.getMonth() + 1}月`)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor("#333333")
              
              Image($r('app.media.layered_image')) // 暂时用这个图标代替下拉箭头，或者直接用文字
                .width(16)
                .height(16)
                .margin({ left: 4 })
                .fillColor("#333333") // 尝试着色，如果不支持会自动忽略
            }
            .width("100%")
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })
            .onClick(() => {
              this.showStatsDatePicker();
            })

            // 概览卡片
            Row() {
              Column() {
                Text("收入")
                  .fontSize(12)
                  .fontColor("#999999")
                Text(`+${this.getMonthlyStats().totalIncome.toFixed(2)}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor("#34C759")
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Divider().vertical(true).height(30).color("#E0E0E0")

              Column() {
                Text("支出")
                  .fontSize(12)
                  .fontColor("#999999")
                Text(`-${this.getMonthlyStats().totalExpense.toFixed(2)}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor("#333333")
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Divider().vertical(true).height(30).color("#E0E0E0")

              Column() {
                Text("结余")
                  .fontSize(12)
                  .fontColor("#999999")
                Text(`${this.getMonthlyStats().balance.toFixed(2)}`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor("#4A6CF7")
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }
            .width("92%")
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 16 })
            .shadow({ radius: 4, color: "#0D000000", offsetY: 2 }) // 优化阴影

            // 收支切换
            Row() {
              Button("支出分析")
                .type(ButtonType.Normal)
                .backgroundColor(this.statsType === 'expense' ? "#4A6CF7" : "#F0F2F5")
                .fontColor(this.statsType === 'expense' ? Color.White : "#666666")
                .borderRadius({ topLeft: 8, bottomLeft: 8 })
                .width("50%")
                .height(32)
                .onClick(() => {
                  this.statsType = 'expense';
                  this.drawPieChart();
                  this.drawBarChart();
                })
              
              Button("收入分析")
                .type(ButtonType.Normal)
                .backgroundColor(this.statsType === 'income' ? "#34C759" : "#F0F2F5")
                .fontColor(this.statsType === 'income' ? Color.White : "#666666")
                .borderRadius({ topRight: 8, bottomRight: 8 })
                .width("50%")
                .height(32)
                .onClick(() => {
                  this.statsType = 'income';
                  this.drawPieChart();
                  this.drawBarChart();
                })
            }
            .width("92%")
            .margin({ bottom: 16 })

            // 饼图 Canvas
            Column() {
              Text("分类占比")
                .fontSize(14)
                .fontColor("#666666")
                .width("100%")
                .margin({ bottom: 8 })

              Canvas(this.context)
                .width("100%")
                .height(200)
                .onReady(() => {
                  this.drawPieChart();
                })
                .onAreaChange(() => {
                   this.drawPieChart();
                })
            }
            .width("92%")
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 16 })
            .shadow({ radius: 4, color: "#0D000000", offsetY: 2 })

            // 每日趋势 Canvas
            Column() {
              Text("每日趋势")
                .fontSize(14)
                .fontColor("#666666")
                .width("100%")
                .margin({ bottom: 8 })

              Canvas(this.barContext)
                .width("100%")
                .height(150)
                .onReady(() => {
                  this.drawBarChart();
                })
                .onAreaChange(() => {
                   this.drawBarChart();
                })
            }
            .width("92%")
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 16 })
            .shadow({ radius: 4, color: "#0D000000", offsetY: 2 })

            // 分类列表
            List() {
              ForEach(this.getPieData(), (item: PieData) => {
                ListItem() {
                  Row() {
                    // Color dot
                    Circle({ width: 10, height: 10 })
                      .fill(item.color)
                      .margin({ right: 8 })
                    
                    Text(item.category)
                      .fontSize(14)
                      .fontColor("#333333")
                      .layoutWeight(1)
                    
                    Text(`${(item.percentage * 100).toFixed(1)}%`)
                      .fontSize(14)
                      .fontColor("#666666")
                      .margin({ right: 16 })
                    
                    Text(item.amount.toFixed(2))
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor("#333333")
                  }
                  .width("100%")
                  .padding({ top: 12, bottom: 12 })
                  .border({ width: { bottom: 1 }, color: "#F0F0F0" })
                }
              })
            }
            .width("92%")
            .layoutWeight(1)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .padding(16)
            .shadow({ radius: 4, color: "#0D000000", offsetY: 2 }) // 优化阴影
          }
          .width("100%")
          .height("100%")
          .backgroundColor("#F9FAFB")
          .alignItems(HorizontalAlign.Center)
        }
        .tabBar(this.TabBuilder("统计", 2, "📊"))
      }
      .barWidth("100%")
      .barHeight(60)
      .backgroundColor(Color.White)
      .layoutWeight(1) // 确保Tabs占据剩余空间，避免被顶部标题栏挤出屏幕
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#F9FAFB")
  }
}
