function get_colors(state){
    return {
        NOT_READY: '#FF9800', // Vivid orange
        READY: '#009688', // Teal
        ACW: '#D32F2F', // Deep red
        ON_HOLD: '#FFEB3B', // Burgoise yellow
        ON_PARK: '#9C27B0', // Rich purple
        ON_CALL: '#2196F3', // Cool blue
        LOGGED_IN: '#4CAF50', // Forest green
        LOGGED_OUT: '#F44336', // Bright red
    }[state];
}


function loadTotalTimeSpentInEachState(divId) {
    const states = ["NOT_READY", "READY", "ACW", "ON_HOLD", "ON_PARK", "ON_CALL"].sort();

    // Make a GET request to the API
    fetch('http://localhost:3000/api/GetAgentStateIntervals?pageNumber=-1&state=' + states.join(','))
        .then(response => response.json())
        .then(data => {

            // Get the agent ids
            const agentIds = [...new Set(data.map(item => item.agent_id))];

            // Get the total time spent in each state for each agent
            const totalTimes = data.reduce((acc, item) => {
                const agentId = item.agent_id;
                const {state} = item;
                const time = item.agent_state_time;

                if (!acc[agentId]) {
                    acc[agentId] = {};
                }

                if (!acc[agentId][state]) {
                    acc[agentId][state] = 0;
                }

                acc[agentId][state] += time;

                return acc;
            }, {});

            // Create the data for the chart
            const series = states.map(state => {
                return {
                    name: state,
                    data: agentIds.map(agentId => totalTimes[agentId] ? totalTimes[agentId][state] : 0)
                };
            });

            console.log("Total times:", series);

            // Create the chart
            const chart = new ApexCharts(document.querySelector(divId), {
                chart: {
                    type: "bar",
                    stacked: true,
                    height: 400,
                    background: '#f9f9f9',
                    toolbar: { show: false },
                    animations: {
                        enabled: true,
                        easing: 'easeinout',
                        speed: 800,
                        animateGradually: { enabled: true, delay: 150 },
                        dynamicAnimation: { enabled: true, speed: 350 }
                    },
                    parentHeightOffset: 0
                },
                colors: states.map(get_colors),
                title: {
                    text: "Total Time Spent in Each State",
                    align: 'center',
                    style: { fontSize: '20px', fontWeight: 'bold', color: '#333' }
                },
                legend: {
                    show: true,
                    position: 'top',
                    horizontalAlign: 'center',
                    fontSize: '14px',
                    markers: { radius: 12 }
                },
                grid: {
                    borderColor: '#e0e0e0',
                    strokeDashArray: 4,
                    padding: { left: 20, right: 20 }
                },
                plotOptions: {
                    bar: {
                        horizontal: false,
                        columnWidth: '40%',
                        endingShape: 'rounded',
                        borderRadius: 6,
                        dataLabels: { position: 'top' }
                    }
                },
                dataLabels: {
                    enabled: false
                },
                series: series,
                xaxis: {
                    categories: agentIds.sort(),
                    labels: {
                        rotate: -45,
                        style: { fontSize: '13px', colors: '#555' }
                    },
                    axisBorder: { show: false },
                    axisTicks: { show: false },
                    title: {
                        text: 'Agent IDs',
                        style: { fontSize: '15px', color: '#555' }
                    }
                },
                yaxis: {
                    title: {
                        text: 'Total Time Spent (Hours)',
                        style: { fontSize: '15px', color: '#555' }
                    },
                    labels: {
                        formatter: function(val) { return Math.floor(val / 3600) + ' hours'; },
                        style: { fontSize: '13px', colors: '#555' },
                    },
                    stepSize: 18000, // 5 hours in seconds
                    forceNiceScale: true,
                },
                fill: {
                    opacity: 0.85
                },
                tooltip: {
                    theme: 'light',
                    y: {
                        formatter: function (val) {
                            return `${(val / 3600).toFixed(2)} hours`;
                        }
                    }
                },
                responsive: [{
                    breakpoint: 600,
                    options: {
                        chart: { height: 300 },
                        legend: { position: 'bottom', fontSize: '12px' },
                        xaxis: { labels: { rotate: 0 } }
                    }
                }]
            });
            chart.render();
        })
        .catch(error => console.error(error));
}

async function loadAgentStateDistribution(divId) {
    const states = ["NOT_READY", "READY", "ACW", "ON_HOLD", "ON_PARK", "ON_CALL"];
    fetch('http://localhost:3000/api/GetAgentStateIntervals?pageNumber=-1&state=' + states.join(','))
        .then(response => response.json())
        .then(data => {
            // Aggregate agent_state_time by state
            let stateTimes = {};
            data.forEach(item => {
                const {state} = item;
                const time = parseInt(item.agent_state_time, 10);
                stateTimes[state] = (stateTimes[state] || 0) + time;
            });

            console.log("State times:", stateTimes);

            stateTimes = Object.entries(stateTimes)
                .sort((a, b) => a[0].localeCompare(b[0]))
                .reduce((obj, [key, value]) => ({ ...obj, [key]: value }), {});

            // Prepare data for ApexCharts
            const series = Object.values(stateTimes);
            const states = Object.keys(stateTimes);
            
            // Define chart options
            const options = {
                chart: {
                    type: 'pie',
                    height: '100%',
                    dropShadow: {
                        enabled: true,
                        top: 2,
                        left: 2,
                        blur: 4,
                        color: '#888',
                        opacity: 0.2
                    },
                    background: '#f9f9f9'
                },
                colors: states.map(get_colors),
                series: series,
                labels: states,
                legend: {
                    position: 'right',
                    fontSize: '16px',
                    fontWeight: 500,
                    markers: {
                        width: 16,
                        height: 16,
                        radius: 8
                    }
                },
                dataLabels: {
                    enabled: true,
                    formatter: function (val, opts) {
                        return val.toFixed(1) + "%";
                    },
                    style: {
                        fontSize: '15px',
                        fontWeight: 'bold',
                        colors: ['#333']
                    },
                    dropShadow: {
                        enabled: true,
                        top: 1,
                        left: 1,
                        blur: 1,
                        color: '#000',
                        opacity: 0.1
                    }
                },
                responsive: [{
                    breakpoint: 480,
                    options: {
                        chart: {
                            width: 200
                        },
                        legend: {
                            position: 'bottom',
                            fontSize: '12px'
                        }
                    }
                }],
                title: {
                    text: 'Agent State Distribution',
                    align: 'center',
                    style: {
                        fontSize: '20px',
                        fontWeight: 'bold',
                        color: '#222'
                    },
                    offsetX: -55,
                    margin: 50,
                },
                tooltip: {
                    y: {
                        formatter: function (val) {
                            return `${(val / 3600).toFixed(2)} hours`;
                        }
                    }
                },
                plotOptions: {
                    pie: {
                        offsetX: 0,
                        customScale: 1.05,
                        donut: {
                            size: '65%',
                        },
                        expandOnClick: true,
                        dataLabels: {
                            offset: 0
                        }
                        
                    },
                },
                stroke: {
                    show: true,
                    width: 2,
                    colors: ['#fff']
                }
            };
        
            // Render the chart
            const chart = new ApexCharts(document.querySelector(divId), options);
            chart.render();
        })
        .catch(error => console.error(error));
}


async function loadAgentUtilization(divId, startDate, endDate) {
    const states = ["LOGGED_IN", "ON_CALL", "ACW", "ON_HOLD"];
    fetch('http://localhost:3000/api/GetAgentStateIntervals?pageNumber=-1&startDate=' + startDate + '&endDate=' + endDate + '&state=' + states.join(','))
        .then(response => response.json())
        .then(data => {

            // Aggregate data by 15min
            const hourlyUtilization = {};
            const dateRange = [];
            let d = new Date(startDate);
            const end = new Date(endDate);

            // Generate 15min labels
            while (d <= end) {
                const quarterHourLabel = d.toISOString().slice(0, 14) + (d.getMinutes() < 45 ? (d.getMinutes() < 15 ? '00' : '15') : (d.getMinutes() < 60 ? '30' : '45'));
                dateRange.push(quarterHourLabel);
                hourlyUtilization[quarterHourLabel] = { productive: 0, loggedIn: 0 };
                d.setMinutes(d.getMinutes() + 15);
            }

            // Aggregate agent_state_time by 15min and state
            data.forEach(item => {
                const quarterHourLabel = new Date(item.interval).toISOString().slice(0, 14) + (new Date(item.interval).getMinutes() < 45 ? (new Date(item.interval).getMinutes() < 15 ? '00' : '15') : (new Date(item.interval).getMinutes() < 60 ? '30' : '45'));
                const {state} = item;
                const time = parseInt(item.agent_state_time, 10);

                const productiveStates = ['ON_CALL', 'ACW', 'ON_HOLD'];

                if (hourlyUtilization[quarterHourLabel]) {
                    if (productiveStates.includes(state)) {
                        hourlyUtilization[quarterHourLabel].productive += time;
                    }
                    if (state === 'LOGGED_IN') {
                        hourlyUtilization[quarterHourLabel].loggedIn += time;
                    }
                }
            });

            // Calculate utilization percentage per 15min
            const series = dateRange.map(quarterHour => {
                const { productive, loggedIn } = hourlyUtilization[quarterHour];
                return {
                    x: new Date(quarterHour).getTime(),
                    y: loggedIn > 0 ? Math.min(((productive / loggedIn) * 100).toFixed(2), 100) : 0
                };
            });

            console.log("Hourly Utilization:", hourlyUtilization);

            // Define chart options
            const options = {
                chart: {
                    type: 'area',
                    height: 350,
                    zoom: {
                        autoScaleYaxis: true
                    },
                    background: '#f9f9f9'
                },
                series: [{
                    name: 'Agent Utilization (%)',
                    data: series
                }],
                xaxis: {
                    type: 'datetime',
                    title: { text: 'Time' },
                    labels: {
                        rotate: -45,
                    }
                },
                yaxis: {
                    title: { text: 'Utilization (%)' }
                },
                title: {
                    text: 'Agent Utilization Over Time',
                    align: 'center'
                },
                tooltip: {
                    x: {
                        format: 'yyyy-MM-dd HH:mm'
                    },
                    y: {
                        formatter: function (val) {
                            return `${val}%`;
                        }
                    }
                },
                dataLabels: {
                enabled: false
                }
            };

            // Render the chart
            document.querySelector(divId).innerHTML = '';
            const chart = new ApexCharts(document.querySelector(divId), options);
            chart.render();
        })
        .catch(error => console.error(error));
}

function loadCallEfficiency(divId) {
/*
Call Hold and Park Time Analysis (Doughnut Chart)
Purpose: Highlight time spent in ON_HOLD and ON_PARK states to assess call handling efficiency.
Data: Sum agent_state_time for ON_HOLD and ON_PARK states across all agents, compared to total time in other states.
Use Case: Reduce excessive hold or park times to improve customer experience.
*/

    const states = ["ON_HOLD", "ON_PARK", "ON_CALL"].sort();
    fetch('http://localhost:3000/api/GetAgentStateIntervals?pageNumber=-1&state=' + states.join(','))
        .then(response => response.json())
        .then(data => {
            // Aggregate time for each state in the order of 'states'
            let stateTimes = {};
            data.forEach(item => {
                const {state} = item;
                const time = parseInt(item.agent_state_time, 10);
                stateTimes[state] = (stateTimes[state] || 0) + time;
            });

            // Ensure series order matches states order
            const series = states.map(state => stateTimes[state] || 0);

            // Define chart options
            const options = {
                chart: {
                    type: 'donut',
                    height: '100%',
                    dropShadow: {
                        enabled: true,
                        blur: 4,
                        color: '#888',
                        opacity: 0.2
                    },
                    background: '#f9f9f9',
                    animations: {
                        enabled: true,
                        easing: 'easeinout',
                        speed: 900,
                        animateGradually: { enabled: true, delay: 200 },
                        dynamicAnimation: { enabled: true, speed: 400 }
                    }
                },
                colors: states.map(get_colors),
                series: series,
                labels: states,
                legend: {
                    position: 'bottom',
                    fontSize: '16px',
                    fontWeight: 500,
                    markers: {
                        width: 16,
                        height: 16,
                        radius: 8
                    },
                    itemMargin: {
                        horizontal: 12,
                        vertical: 8
                    }
                },
                dataLabels: {
                    enabled: true,
                    formatter: function (val, opts) {
                        return val.toFixed(1) + "%";
                    },
                    style: {
                        fontSize: '12px',
                        fontWeight: 'bold',
                        colors: ['#333']
                    },
                    dropShadow: {
                        enabled: true,
                        top: 1,
                        left: 1,
                        blur: 1,
                        color: '#000',
                        opacity: 0.1
                    }
                },
                title: {
                    text: 'Call Hold and Park Time Analysis',
                    align: 'center',
                    style: {
                        fontSize: '22px',
                        fontWeight: 'bold',
                        color: '#222'
                    },
                    offsetY: 10,
                    margin: 30,
                },
                tooltip: {
                    y: {
                        formatter: function (val) {
                            return `${(val / 3600).toFixed(2)} hours`;
                        }
                    }
                },
                plotOptions: {
                    pie: {
                        donut: {
                            size: '65%',
                        },
                        expandOnClick: true,
                    }
                },
                stroke: {
                    show: true,
                    width: 2,
                    colors: ['#fff']
                },
                responsive: [{
                    breakpoint: 480,
                    options: {
                        chart: {
                            width: 200
                        },
                        legend: {
                            position: 'bottom',
                            fontSize: '12px'
                        }
                    }
                }]
            };

            // Render the chart
            document.querySelector(divId).innerHTML = '';
            const chart = new ApexCharts(document.querySelector(divId), options);
            chart.render();
        })
        .catch(error => console.error(error));
}