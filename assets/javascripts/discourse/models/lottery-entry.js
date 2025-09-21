import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

const LotteryEntry = RestModel.extend({
  // 计算属性
  isRunning: function() {
    return this.status === "running";
  }.property("status"),
  
  isFinished: function() {
    return this.status === "finished";
  }.property("status"),
  
  isCancelled: function() {
    return this.status === "cancelled";
  }.property("status"),
  
  isRandomType: function() {
    return this.lottery_type === "random";
  }.property("lottery_type"),
  
  isSpecifiedType: function() {
    return this.lottery_type === "specified";
  }.property("lottery_type"),
  
  drawTimeDate: function() {
    return new Date(this.draw_time);
  }.property("draw_time"),
  
  specifiedFloorsArray: function() {
    if (!this.specified_floors) return [];
    return this.specified_floors.split(',').map(f => parseInt(f.trim()));
  }.property("specified_floors"),
  
  hasWinners: function() {
    return this.winners_data && this.winners_data.length > 0;
  }.property("winners_data"),
  
  winnersCount: function() {
    return this.winners_data ? this.winners_data.length : 0;
  }.property("winners_data"),
  
  formattedDrawTime: function() {
    if (!this.draw_time) return "";
    
    return new Date(this.draw_time).toLocaleString("zh-CN", {
      year: "numeric",
      month: "2-digit", 
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    });
  }.property("draw_time"),
  
  timeUntilDraw: function() {
    if (!this.draw_time) return 0;
    
    const now = Date.now();
    const drawTime = new Date(this.draw_time).getTime();
    return Math.max(0, drawTime - now);
  }.property("draw_time"),
  
  canEdit: function() {
    if (!this.isRunning) return false;
    
    const lockDelay = 30 * 60 * 1000; // 30分钟，应该从设置获取
    const drawTime = new Date(this.draw_time).getTime();
    const lockTime = drawTime - lockDelay;
    
    return Date.now() < lockTime;
  }.property("draw_time", "status"),
  
  progressPercentage: function() {
    if (!this.min_participants || this.min_participants <= 0) return 0;
    
    const current = this.participants_count || 0;
    return Math.min((current / this.min_participants) * 100, 100);
  }.property("participants_count", "min_participants"),
  
  meetsMinimumParticipants: function() {
    const current = this.participants_count || 0;
    return current >= this.min_participants;
  }.property("participants_count", "min_participants"),
  
  // 方法
  update(data) {
    return ajax(`/lottery/${this.topic_id}`, {
      type: "PUT",
      data: data
    }).then(result => {
      this.setProperties(result.lottery);
      return this;
    });
  },
  
  refresh() {
    return ajax(`/lottery/${this.topic_id}`).then(result => {
      this.setProperties(result.lottery);
      return this;
    });
  },
  
  getWinnersFormatted() {
    if (!this.hasWinners) return [];
    
    return this.winners_data.map((winner, index) => {
      return {
        rank: index + 1,
        username: winner.username,
        floor: winner.floor,
        post_id: winner.post_id,
        user_id: winner.user_id
      };
    });
  },
  
  getSpecifiedFloorsText() {
    if (!this.isSpecifiedType || !this.specified_floors) return "";
    return this.specified_floors.split(',').map(f => f.trim()).join('、') + "楼";
  },
  
  getBackupStrategyText() {
    return this.backup_strategy === "continue" ? 
      "人数不足时继续开奖" : "人数不足时取消活动";
  },
  
  // 静态方法
  findByTopicId(topicId) {
    return ajax(`/lottery/${topicId}`).then(result => {
      return LotteryEntry.create(result.lottery);
    });
  }
});

LotteryEntry.reopenClass({
  createRecord(attributes) {
    return this.create(attributes);
  },
  
  findAll() {
    return ajax("/lottery").then(result => {
      return result.lotteries.map(lottery => LotteryEntry.create(lottery));
    });
  }
});

export default LotteryEntry;
