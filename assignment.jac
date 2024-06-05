import:py random;
import:py sys;
import:py from jaclang.core.llms, Anthropic;

glob llm = Anthropic(model_name="claude-3-sonnet-20240229");

'''
User node has user_name attribute.
'''
node user{
    has user_name:string="user";
}

'''
Chat session of a user. This node contains the session_id, user_data and todo_list.
This should also include the chat history. Can have multiple chat sessions.
'''
node session{
    has session_id : string = 100;
    has user_data : dict = {}; # User data such as habits, heart rate etc.
    has todo_list : list = []; # List of things to do by the user.
    has chat_history: dict = []; # store the chat history.
}

'''
Consists of user data such as age, pressure, married status.
'''
node data{
    has user_data:dict = {
                "age" : 0,
                "Pressure" : (0,0),
                "Married" : False
                };
}

'''
List of things to do by the user.
'''
node todo{
    has todo_list:list = [];
}


'''
This is the chat walker which will be used to chat with the user.
The create_session ability:
    - gather the user data and todo list from connected nodes using filters.
    - Creates a new session with the user data and todo list.
    - Spawns the chat session with the session id.
'''
walker chat{

    can create_session with user entry;
    can chat_session with session entry;
    can view_chat_history with session entry;

}

'''
This is where we create the graph.
'''
walker create_graph{
    has user_data:dict = {};
    has todo_list:list = [];

    can generate_graph with `root entry;
}

'''
This is the query walker which will be used to query a user input and generate a response.
The init_query_engine ability:
    - Gathers the user data and todo list from the user node.
    - Asks the user for the routing method.
    - Creates a router node and connects it to the RAG_chat, todo_chat and user_qa_chat nodes.
    - Visits the router node.
'''
walker query{
    has query:str = '';
    has user_session_id:str='';
    has session_chat_history:list=[];
    has user_data: 'data about the health status of the user' :dict={};
    has todo_list: 'The tasks to be done by the user in the future.' :list=[];
    has response:str='';  # Add response attribute to store the generated response


    can init_query_engine with session entry;

}

'''
This is the router node which will be used to route the user query to the appropriate chat node.
TODO:Auto-routing feature not yet implemented
'''
node router {
    can route with query entry;
}

'''
This is the RAG chat node which will be used to chat with the user using Retrival Augmented Generation.
TODO:Not yet implemented.
'''
node RAG_chat {
    can run_RAG with query entry {
        print('routed --> RAG');
        print('response from RAG');
        generated_response = 'response from RAG';  # Replace with actual RAG processing
        here.response = generated_response;

    }
}

'''
This is the TODO chat node which will be used to chat with the user using the todo list and user data.
'''
node todo_chat {
    can run_todo with query entry {
        print('routed --> TODO');
        here.response = self.chat_llm(user_data=here.user_data, todo_list=here.todo_list, query=here.query);
        print(here.response);
    }

    can 'You are a Health Assistant. Give a response based on the query using my user data dict and todo list.' chat_llm(
        user_data: dict,
        todo_list: list,
        query: str
    ) -> str by llm();
}
'''
This is the user QA chat node which will be used to chat with the user using the user data.
TODO:Not yet implemented.
'''
node user_qa_chat {
    can run_user_qa with query entry {
        print('routed --> USER_QA');
        here.response = self.chat_llm(user_data=here.user_data, query=here.query);
        print(here.response);
    }

    can 'You are a Health Assistant. Give a response based on the query using my user data dict.' chat_llm(
        user_data: dict,
        query: str
    ) -> str by llm();
}

with entry {
    create_graph(   user_data={ "age": 20,
                                "Pressure": (120, 80),
                                "Married": False
                            },
                     todo_list=["Do heart surgery : 04/12/2020",
                                "Run Marathon : 14/12/2020",
                                "Doctor's appointment : 20/12/2020"]
                ) spawn root;
}

## Implementations ==================================================================================================================

:walker:chat:can:create_session {

        # Telescope into the nodes connected to the user node without walking.
        data_node = [-->](`?data)[0]; # Getting the data node filtered. can use [0] as having only one such node.
        todo_node = [-->](`?todo)[0]; # Getting the todo node filtered. can use [0] as having only one such node.
        new_session_id = str(random.randint(1,100));

        # Creating a new session node with the user data and todo list and connect it to the user.
        n = here ++> session(   session_id = new_session_id,
                            user_data = data_node.user_data,
                            todo_list = todo_node.todo_list
                        );
        visit n;
    }

:walker:chat:can:chat_session {
    # print(here.user_data);
    # print(here.todo_list);
    
    while True {
        query_str:str = input("Do you want to continue (or type 'exit' to quit): ");
        if query_str.lower() == 'exit'{
            sys.exit();
        }

        elif query_str.lower() == 'history'{        # Check if the user wants to view chat history
            self.view_chat_history(here);  # Call the view_chat_history walker
            
        } 

        elif query_str.lower() in ['yes','Yes','YES']{
            q = query() spawn here;

        # Add query to chat history
            here.chat_history.append({"user": q.query});

        # Process the query by spawning the query walker
        
        # q.query = query;
        # visit q;
            
        # Add response to chat history
            here.chat_history.append({"bot": q.response});
        }

        else{
            print('Inappropriate request');
            continue;
        }
        
        }
    }

:walker:chat:can:view_chat_history{
    print();
    print("Chat History:");
    here ++> session();  # Set the current node to session
    for entry in here.chat_history{
        if "user" in entry{
            print("User:", entry["user"]);
        }
            
        elif "bot" in entry{
            print("Bot:", entry["bot"]);
        }
            
    }
        
}

:walker:create_graph:can:generate_graph {
    end = here; # Assign the current root node (here) to end
    end ++> (end := user()); # Create a user node and connect it to the end node. Assign the new user node to the end.
    end ++> data(user_data = self.user_data); # Create a data node with the user data and connect it to the end node.
    end ++> todo(todo_list = self.todo_list); # Create a todo node with the todo list and connect it to the end node.
    chat() spawn [-->](`?user)[0]; # Spawn the chat walker with the user node.
}

:walker:query:can:init_query_engine {
    self.user_data:dict = here.user_data;
    self.todo_list:list = here.todo_list;
    self.task_type:str = input('What is the routing method : ');
    self.query:str = input('Enter your query : ');

    end = here;
    end ++> (end := router());
    # end ++> RAG_chat();
    # end ++> todo_chat();
    # end ++> user_qa_chat();

    visit [-->];
}

:node:router:can:route {
    task:str = here.task_type;
    if task == 'RAG' {
        visit [-->](`?RAG_chat);
        RAG_chat() spawn here;
    } elif task == 'QA'{
        visit [-->](`?user_qa_chat);
        user_qa_chat() spawn here;
    } elif task == 'TODO' {
        visit [-->](`?todo_chat);
        todo_chat() spawn here;
    }
}