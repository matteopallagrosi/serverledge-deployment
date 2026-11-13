from locust import HttpUser, task, constant_throughput, events
import random, json
from threading import Lock

try:
    with open("input.json", "r") as f:
        car_params = json.load(f)
except FileNotFoundError:
    car_params = {}

WORKFLOWS = [
    {
        "name": "sentiment-analysis",
        "payload": {
            "Params": {
                "data_url": "https://matteonardelli.it/resources/amazon_review_polarity_csv2.tgz",
                "subset": 0.01,
                "la_max_features": 10,
                "ha_max_features": 100
            },
            "CanDoOffloading": True,
            "Async": False,
            "QoS": {"Class": 0, "MaxRespT": -1.0}
        }
    },
    {
        "name": "detection",
        "payload": {
            "Params": car_params,
            "CanDoOffloading": True,
            "Async": False,
            "QoS": {"Class": 0, "MaxRespT": -1.0}
        }
    }
]

class ResponseLogger:
    def __init__(self, output_file):
        self.output_file = output_file
        self.responses_buffer = []
        self.lock = Lock()

    def add_response(self, url, response_time, status_code, jsonresp):
        """Add a response to the buffer (thread-safe)"""
        with self.lock:
            total_init = 0
            total_duration = 0
            func_area = []
            func_node = []
            func_warm = []
            func_duration = []
            try:
                reports = jsonresp["Reports"]
                for func, freport in reports.items():
                    func_area.append(f"{func}:{freport['ExecutionArea']}")
                    func_node.append(f"{func}:{freport['ExecutionNode']}")
                    func_warm.append(f"{func}:{freport['IsWarmStart']}")
                    duration = float(freport['Duration'])
                    init_time = float(freport['InitTime'])-float(freport['QueueingTime'])
                    func_duration.append(f"{func}:{duration+init_time}")
                    total_init += float(freport['InitTime'])
                    total_duration += duration
            except:
                pass
            areastr = "|".join(func_area)
            nodestr = "|".join(func_node)
            warmstr = "|".join(func_warm)
            durationstr = "|".join([str(x) for x in func_duration])

            try:
                scheduling_time = float(jsonresp["SchedulingTime"])
            except:
                scheduling_time = -1

            entry = f"{status_code}; {response_time}; {url}; {areastr}; {nodestr}; {warmstr}; {total_init}; {total_duration}; {durationstr}; {scheduling_time}"
            self.responses_buffer.append(entry)

    def flush_to_file(self):
        with self.lock:
            if not self.responses_buffer: return
            with open(self.output_file, 'w') as f:
                for response in self.responses_buffer:
                    f.write(f"{response}\n")

response_logger = ResponseLogger(output_file='response_times.txt')

@events.test_start.add_listener
def on_locust_init(environment, **kwargs):
    pass

@events.test_stop.add_listener
def stop_handler(environment, **kw):
    response_logger.flush_to_file()

class MyUser(HttpUser):
    wait_time = constant_throughput(1) 

    @task
    def invoke_workflow(self):
        # Sceglie il workflow con pesi: 30% sentiment-analysis, 70% car-detection
        workflow = random.choices(WORKFLOWS, weights=[30, 70], k=1)[0]
        
        self.client.post(
            f"/workflow/invoke/{workflow['name']}", 
            json=workflow['payload'], 
            timeout=120
        )

    @events.request.add_listener
    def my_request_handler(request_type, name, response_time, response_length, response, **kwargs):
        try:
            jsonresp = response.json()
        except:
            jsonresp = {}
        clean_name = name.split("/")[-1] 
        response_logger.add_response(clean_name, response_time, response.status_code, jsonresp)