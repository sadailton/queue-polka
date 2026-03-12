#include <bm/bm_sim/_assert.h>
#include <bm/bm_sim/parser.h>
#include <bm/bm_sim/tables.h>
#include <bm/bm_sim/logger.h>
#include <bm/bm_sim/extern.h>

#include <unistd.h>

#include <condition_variable>
#include <deque>
#include <fstream>
#include <iostream>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>

#include <queue>

#include "simple_switch.h"
#include "register_access.h"
#include <user_externs_WDRR/WDRR_adailton.h>

std::vector<std::shared_ptr<bm::hier_scheduler::flow_scheduler>> bm::hier_scheduler::FS = { NULL}; // one level
//std::vector<std::shared_ptr<bm::hier_scheduler::flow_scheduler>> bm::hier_scheduler::FS = { NULL, NULL, NULL}; // 2 levels
//std::vector<std::shared_ptr<bm::hier_scheduler::flow_scheduler>> bm::hier_scheduler::FS = { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL}; // 3 levels
//std::vector<std::shared_ptr<bm::hier_scheduler::flow_scheduler>> bm::hier_scheduler::FS = { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, NULL, NULL, NULL, NULL, NULL }; // 5 levels


std::vector<std::shared_ptr<bm::hier_scheduler::fifo_bank>> bm::hier_scheduler::FB = { NULL}; // one level
//std::vector<std::shared_ptr<bm::hier_scheduler::fifo_bank>> bm::hier_scheduler::FB = { NULL, NULL}; // 2 levels
//std::vector<std::shared_ptr<bm::hier_scheduler::fifo_bank>> bm::hier_scheduler::FB = { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL}; // 3 levels
//std::vector<std::shared_ptr<bm::hier_scheduler::fifo_bank>> bm::hier_scheduler::FB = { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL}; // 3 levels

unsigned int bm::hier_scheduler::time_now = 0;
unsigned int bm::hier_scheduler::number_levels = 1; // one level
//unsigned int bm::hier_scheduler::number_levels = 2; // 2 levels
//unsigned int bm::hier_scheduler::number_levels = 3; // 3 levels
//unsigned int bm::hier_scheduler::number_levels = 5; // 5 levels


std::vector<unsigned int> bm::hier_scheduler::number_of_queues_per_level = {1}; // one level
//std::vector<unsigned int> bm::hier_scheduler::number_of_queues_per_level = {2,1}; // 2 levels
//std::vector<unsigned int> bm::hier_scheduler::number_of_queues_per_level = {8,2,1}; // 3 levels
//std::vector<unsigned int> bm::hier_scheduler::number_of_queues_per_level = {16,8,4,2,1}; // 5 levels

std::vector<unsigned int> bm::hier_scheduler::number_of_pkts_per_queue_each_level = {2}; // one level
//std::vector<unsigned int> bm::hier_scheduler::number_of_pkts_per_queue_each_level = {4 ,bm::hier_scheduler::number_of_queues_per_level[0]}; // 2 levels
//std::vector<unsigned int> bm::hier_scheduler::number_of_pkts_per_queue_each_level = {10 ,bm::hier_scheduler::number_of_queues_per_level[0]/bm::hier_scheduler::number_of_queues_per_level[1] ,bm::hier_scheduler::number_of_queues_per_level[1]}; // 3 levels
//std::vector<unsigned int> bm::hier_scheduler::number_of_pkts_per_queue_each_level = {80 ,bm::hier_scheduler::number_of_queues_per_level[0]/bm::hier_scheduler::number_of_queues_per_level[1],bm::hier_scheduler::number_of_queues_per_level[1]/bm::hier_scheduler::number_of_queues_per_level[2],bm::hier_scheduler::number_of_queues_per_level[2]/bm::hier_scheduler::number_of_queues_per_level[3] ,bm::hier_scheduler::number_of_queues_per_level[3]}; // 5 levels


unsigned int sum_all_queues = bm::hier_scheduler::number_of_queues_per_level[0]; // one level
//unsigned int sum_all_queues = bm::hier_scheduler::number_of_queues_per_level[0] + bm::hier_scheduler::number_of_queues_per_level[1]; // 2 levels
//unsigned int sum_all_queues = bm::hier_scheduler::number_of_queues_per_level[0] + bm::hier_scheduler::number_of_queues_per_level[1] + bm::hier_scheduler::number_of_queues_per_level[2]; // 3 levels
//unsigned int sum_all_queues = bm::hier_scheduler::number_of_queues_per_level[0] + bm::hier_scheduler::number_of_queues_per_level[1] + bm::hier_scheduler::number_of_queues_per_level[2] + bm::hier_scheduler::number_of_queues_per_level[3] + bm::hier_scheduler::number_of_queues_per_level[4]; // 5 levels

std::vector<unsigned int> bm::hier_scheduler::error_detected_each_level(sum_all_queues);
std::vector<unsigned int> bm::hier_scheduler::internal_force_flow_id_each_level(sum_all_queues);

unsigned int number_of_update_ranks_all_level = (bm::hier_scheduler::number_of_pkts_per_queue_each_level[0]*bm::hier_scheduler::number_of_queues_per_level[0] * bm::hier_scheduler::number_levels); // one level
//unsigned int number_of_update_ranks_all_level = bm::hier_scheduler::number_of_queues_per_level[0]  + (bm::hier_scheduler::number_of_pkts_per_queue_each_level[0]*bm::hier_scheduler::number_of_queues_per_level[0] * bm::hier_scheduler::number_levels); // 2 levels
//unsigned int number_of_update_ranks_all_level = bm::hier_scheduler::number_of_queues_per_level[1] + bm::hier_scheduler::number_of_queues_per_level[0]  + (bm::hier_scheduler::number_of_pkts_per_queue_each_level[0]*bm::hier_scheduler::number_of_queues_per_level[0] * bm::hier_scheduler::number_levels); // 3 levels
//unsigned int number_of_update_ranks_all_level = bm::hier_scheduler::number_of_queues_per_level[3] + bm::hier_scheduler::number_of_queues_per_level[2] + bm::hier_scheduler::number_of_queues_per_level[1] + bm::hier_scheduler::number_of_queues_per_level[0]  + (bm::hier_scheduler::number_of_pkts_per_queue_each_level[0]*bm::hier_scheduler::number_of_queues_per_level[0] * bm::hier_scheduler::number_levels); // 5 levels

std::vector<unsigned int> bm::hier_scheduler::new_ranks_each_level(number_of_update_ranks_all_level);


std::queue<unsigned int> bm::hier_scheduler::pkt_ptr_queue;

unsigned int bm::hier_scheduler::use_updated_rank = 0;
unsigned int bm::hier_scheduler::last_force_deq = 0;
unsigned int bm::hier_scheduler::force_deq_flow_id = 0;
//unsigned int bm::hier_scheduler::shaping = 0;
bool bm::hier_scheduler::shaping = false;
unsigned int bm::hier_scheduler::enable_error_correction = 0;
unsigned int bm::hier_scheduler::number_of_enqueue_packets = 0;
std::vector<unsigned int> bm::hier_scheduler::pkt_levels_ranks = {0}; // 1 level
//std::vector<unsigned int> bm::hier_scheduler::pkt_levels_ranks = {0,0}; // 2 levels
//std::vector<unsigned int> bm::hier_scheduler::pkt_levels_ranks = {0,0,0}; // 3 levels
//std::vector<unsigned int> bm::hier_scheduler::pkt_levels_ranks = {0,0,0,0,0}; // 5 levels

unsigned int bm::hier_scheduler::number_of_read_packets = 0;
unsigned int bm::hier_scheduler::number_of_dequeue_packets = 0;
unsigned int bm::hier_scheduler::switch_is_ready = 1;

int bm::hier_scheduler::start_time = 0;
int bm::hier_scheduler::last_time = 0;

std::vector<unsigned int> bm::hier_scheduler::quota_each_queue = {10500, 4500};
std::vector<unsigned int> bm::hier_scheduler::quantums = {10500, 4500};
unsigned int bm::hier_scheduler::active_queue = 0;

// Mutex e variável de condição para sincronização
//std::mutex bm::hier_scheduler::sync_mutex;
//std::condition_variable bm::hier_scheduler::sync_cv;

//bool dequeued_pointers[50000] = {0};
std::queue<unsigned int> pkt_ptr_queue;


namespace {
	class TM_buffer{
    bm::hier_scheduler dequeue_scheduler;
public:
    static std::unordered_map<unsigned int, std::unique_ptr<Packet>> packet_map;
    static std::unordered_map<unsigned int, bool> dropped_pointers;

    unsigned int valid_pop(std::unique_ptr<Packet>& packet)
    {
        static double tokens = 625000.0; // Exatos 5 Mbps
        static auto last_time = std::chrono::high_resolution_clock::now();
        static bool init_tb = false;
        
        if (!init_tb) {
            last_time = std::chrono::high_resolution_clock::now();
            init_tb = true;
        }

        // 1. INGRESSO E TAIL DROP (Limite da represa: 1000 pacotes)
        if(packet != NULL)
        {
            unsigned int in_ptr = dequeue_scheduler.get_last_pkt_ptr();
            if (packet_map.size() < 1000) {
                packet_map[in_ptr] = std::move(packet);
            } else {
                // Fila cheia! Destrói o pacote na entrada.
                packet = NULL; 
                dropped_pointers[in_ptr] = true; // Avisa o WDRR que este pacote morreu
            }
        }

        unsigned int valid_packet = 0;
        packet = NULL;
        unsigned int ptr = 0;

        // 2. ATUALIZA FICHAS (Calcula a passagem do tempo)
        double rate_bytes_per_sec = 625000.0;
        auto now = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> elapsed = now - last_time;
        last_time = now;
        tokens += elapsed.count() * rate_bytes_per_sec;
        if (tokens > rate_bytes_per_sec) tokens = rate_bytes_per_sec;

        // 3. WDRR ESCOLHE O PRÓXIMO
        if(dequeue_scheduler.number_of_deq_pkts() < dequeue_scheduler.number_of_enq_pkts())
        {
            ptr = dequeue_scheduler.dequeue_my_scheduler();
        }

        if((ptr != 0)||(!pkt_ptr_queue.empty()))
        {
            if(ptr != 0) pkt_ptr_queue.push(ptr);            
            ptr = pkt_ptr_queue.front();

            bool resolved = false;

            auto it = packet_map.find(ptr);
            if(it != packet_map.end())
            {
                size_t pkt_bytes = it->second->get_data_size();
                
                // 4. SHAPER VERDADEIRO
                if (tokens >= pkt_bytes) {
                    // Tem banda: Envia o pacote!
                    tokens -= pkt_bytes;
                    packet = std::move(it->second);
                    packet_map.erase(it);
                    valid_packet = 1;
                    resolved = true;
                } else {
                    // Sem banda: Aguarda! (Não descarta o pacote, não avança a fila)
                    valid_packet = 0;
                    resolved = false;
                }
            }
            else if (dropped_pointers.find(ptr) != dropped_pointers.end())
            {
                // WDRR escolheu um pacote que o Tail Drop matou.
                // Consome a cota, ignora o pacote e segue a vida.
                dropped_pointers.erase(ptr);
                valid_packet = 0; 
                resolved = true;
            }
            else 
            {
                // Pacote está atrasado vindo do BMv2. Aguarda!
                valid_packet = 0;
                resolved = false;
            }

            // 5. AVANÇA A FILA (Apenas se o pacote foi enviado ou confirmado como morto)
            if(resolved)
            {
                dequeue_scheduler.increment_deq_count();
                start_dequeue(1);
                pkt_ptr_queue.pop();
            }
        }
        return valid_packet;
    }

    unsigned int enqueued_packets() { return dequeue_scheduler.number_of_enq_pkts(); }
    unsigned int dequeued_packets() { return dequeue_scheduler.number_of_deq_pkts(); }
    unsigned int num_of_read_pkts() { return dequeue_scheduler.num_of_read_pkts(); }
    void start_dequeue(unsigned int start) { dequeue_scheduler.start_dequeue(start); }
};
	}