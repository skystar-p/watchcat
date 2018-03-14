<template>
  <div>
    <el-checkbox v-model="autoRefresh">3초마다 실시간으로 불러오기</el-checkbox>
    <el-card class="info-row-card" body-style="padding: 10px">
      <el-row :gutter="40">
        <el-col :span="8" class="info">
          <i :class='metric.status === "ok" ? "el-icon-success" : "el-icon-error"'/>
          <span>Status - {{ metric.status }}</span>
        </el-col>
        <el-col :span="8" class="info">
          <i class="el-icon-info"/>
          <span>Name - {{ machine.name }}</span>
        </el-col>
        <el-col :span="8" class="info">
          <i class="el-icon-info"/>
          <span>Host - {{ machine.host }}</span>
        </el-col>
      </el-row>
    </el-card>
    <el-card class="info-row-card" body-style="padding: 5px 10px">
      <div class="tag-header">Tags</div>
      <el-tag
        v-for="tag in machine.tags"
        :key="tag">
        {{ tag }}
      </el-tag>
    </el-card>
    <template v-if="metric.status === 'ok'">
      <el-card class="info-row-card" body-style="padding: 10px">
        <el-row :gutter="40">
          <el-col :span="8" class="info">
            <i class="el-icon-time"/>
            <span>{{ new Date(metric.data.timestamp*1000).toLocaleString() }}</span>
          </el-col>
          <el-col :span="8" class="info" v-if='metric.data.uptime.status === "ok"'>
            <i class="el-icon-date"/>
            <span>{{ uptime(metric.data.uptime.data) }}</span>
          </el-col>
        </el-row>
      </el-card>
      <el-row :gutter="20">
        <el-col :span="6">
          <cpu-card :metric="metric.data.cpu"/>
        </el-col>
        <el-col :span="6">
          <memory-card :metric="metric.data.memory"/>
        </el-col>
      </el-row>
    </template>
    <template v-else>
      <p>Metric is not available</p>
    </template>
  </div>
</template>

<script>
import CpuCard from '~/components/CpuCard.vue'
import MemoryCard from '~/components/MemoryCard.vue'

export default {
  data () {
    return {
      machine: null,
      metric: null,
      autoRefresh: false,
      timer: null
    }
  },

  async asyncData ({ app, params, error }) {
    try {
      let machine, metric
      [machine, metric] = await Promise.all([
        app.$axios.$get('/api/machines/' + params.name),
        app.$axios.$get('/api/metric/' + params.name)
      ])

      return {
        machine,
        metric
      }
    }
    catch (err) {
      error({ statusCode: 404, message: 'Machine not found'})
    }
  },

  created () {
    this.timer = setInterval(function () {
      if (this.autoRefresh) {
        this.fetchMetric()
      }
    }.bind(this), 3000)
  },

  beforeDestroy () {
    clearInterval(this.timer)
  },

  methods: {
    async fetchMetric () {
      let metric = await this.$axios.$get('/api/metric/' + this.machine.name)
      this.metric = metric
    },

    uptime (sec) {
      let hours = Math.floor(sec / 60 / 60)
      let days = Math.floor(hours / 24)
      hours = hours % 24

      return days + ' days ' + hours + ' hours up'
    }
  },

  components: {
    CpuCard,
    MemoryCard
  }
}
</script>

<style>
.tag-header {
  display: inline-block;
  border-right: 1px solid rgb(230,230,230);
  padding-right: 10px;
  margin: 0 5px;
}

.el-tag {
  margin: 2px 5px;
}

i {
  margin-right: 5px;
}

.el-icon-success {
  color: green;
}

.info {
  text-align: center;
  font-size: 16px;
}

.info-row-card {
  margin-bottom: 10px;
}

.card-body {
  display: -webkit-flex;
  display: flex;
  -webkit-flex-direction: column;
  flex-direction: column;
}

.line {
  border-top: 1px solid rgb(230, 230, 230);
}

.el-progress {
  margin: 0px auto 10px auto;
}

.el-card {
  box-shadow: 0 1px 1px 0 rgba(0, 0, 0, .1)
}
</style>