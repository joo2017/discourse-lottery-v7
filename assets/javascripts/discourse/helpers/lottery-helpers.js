import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

// 格式化时间差
registerUnbound("lottery-time-diff", function(futureTime) {
  if (!futureTime) return "";
  
  const now = Date.now();
  const target = new Date(futureTime).getTime();
  const diff = target - now;
  
  if (diff <= 0) {
    return i18n("lottery.time.draw_time_passed");
  }
  
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) {
    return i18n("lottery.time.days_remaining", { count: days });
  } else if (hours > 0) {
    return i18n("lottery.time.hours_remaining", { count: hours });
  } else if (minutes > 0) {
    return i18n("lottery.time.minutes_remaining", { count: minutes });
  } else {
    return i18n("lottery.time.seconds_remaining", { count: seconds });
  }
});

// 格式化抽奖状态
registerUnbound("lottery-status-badge", function(status) {
  let className, text, icon;
  
  switch (status) {
    case "running":
      className = "lottery-status-running";
      text = i18n("lottery.status.running");
      icon = "clock";
      break;
    case "finished":
      className = "lottery-status-finished"; 
      text = i18n("lottery.status.finished");
      icon = "trophy";
      break;
    case "cancelled":
      className = "lottery-status-cancelled";
      text = i18n("lottery.status.cancelled");
      icon = "times";
      break;
    default:
      className = "lottery-status-unknown";
      text = i18n("lottery.status.unknown");
      icon = "question";
  }
  
  return htmlSafe(`
    <span class="lottery-status-badge ${className}">
      <i class="fa fa-${icon}"></i>
      ${text}
    </span>
  `);
});

// 格式化抽奖类型
registerUnbound("lottery-type-text", function(lotteryType, specifiedFloors) {
  if (lotteryType === "specified" && specifiedFloors) {
    const floors = specifiedFloors.split(',').join('、');
    return `${i18n("lottery.type.specified_floors")} (${floors}楼)`;
  }
  return i18n("lottery.type.random");
});

// 格式化楼层列表
registerUnbound("format-floors", function(floorsString) {
  if (!floorsString) return "";
  return floorsString.split(',').map(f => f.trim()).join('、') + "楼";
});

// 检查是否可以编辑抽奖
registerUnbound("can-edit-lottery", function(lotteryData, currentUser) {
  if (!lotteryData || !currentUser || lotteryData.status !== "running") {
    return false;
  }
  
  // 检查时间限制（这里简化处理，实际应该从服务器获取）
  const drawTime = new Date(lotteryData.draw_time).getTime();
  const now = Date.now();
  const lockDelay = 30 * 60 * 1000; // 30分钟，应该从设置中获取
  const lockTime = drawTime - lockDelay;
  
  return now < lockTime;
});

// 格式化中奖者列表
registerUnbound("format-winners", function(winnersData) {
  if (!winnersData || winnersData.length === 0) {
    return htmlSafe('<div class="no-winners">暂无中奖信息</div>');
  }
  
  const winnersList = winnersData.map((winner, index) => {
    return `
      <div class="winner-item">
        <span class="winner-rank">${index + 1}.</span>
        <span class="winner-username">@${winner.username}</span>
        <span class="winner-floor">(${winner.floor}楼)</span>
      </div>
    `;
  }).join('');
  
  return htmlSafe(`<div class="winners-list">${winnersList}</div>`);
});

// 获取抽奖进度百分比
registerUnbound("lottery-progress", function(currentParticipants, minParticipants) {
  if (!minParticipants || minParticipants <= 0) return 0;
  
  const progress = Math.min((currentParticipants / minParticipants) * 100, 100);
  return Math.round(progress);
});

// 格式化备用策略文本
registerUnbound("backup-strategy-text", function(strategy) {
  return strategy === "continue" ? 
    i18n("lottery.backup_strategy.continue") : 
    i18n("lottery.backup_strategy.cancel");
});
