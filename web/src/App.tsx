import { useState, useRef, useEffect, useMemo } from "react";
import { Socket } from "phoenix";
import { v4 as uuid } from "uuid";

type Message = {
  sender: string;
  content: string;
};

export default function Component() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState("");
  const [senderName, setSenderName] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(scrollToBottom, [messages]);

  const channel = useMemo(() => {
    const socket = new Socket("ws://localhost:4000/socket");
    socket.connect();

    // Now that you are connected, you can join channels with a topic.
    // Let's assume you have a channel with a topic named `room` and the
    // subtopic is its id - in this case 42:
    const channel = socket.channel("room:main", {});
    channel
      .join()
      .receive("ok", (resp) => {
        console.log("Joined successfully", resp);
        console.log(resp.messages);
        setMessages(resp.messages);
      })
      .receive("error", (resp) => {
        console.log("Unable to join", resp);
      });

    channel.on("new_msg", (payload) => {
      setMessages((m) => [...m, payload]);
    });
    return channel;
  }, []);
  const handleSendMessage = () => {
    if (newMessage.trim() !== "" && senderName.trim() !== "") {
      const newMsg: Message = {
        sender: senderName.trim(),
        content: newMessage.trim(),
      };
      channel.push("new_msg", newMsg);

      setNewMessage("");
    }
  };

  return (
    <div className="w-full max-w-lg mx-auto bg-white shadow-lg rounded-lg overflow-hidden">
      <div className="bg-gray-100 p-4 border-b">
        <h2 className="text-xl font-semibold text-gray-800">Chat</h2>
      </div>
      <div className="h-96 overflow-y-auto p-4 space-y-4">
        {messages.map((message, i) => (
          <div key={i} className="bg-gray-50 rounded-lg p-3">
            <p className="font-medium text-sm text-gray-900">
              {message.sender}
            </p>
            <p className="text-gray-700 mt-1">{message.content}</p>
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>
      <div className="bg-gray-100 p-4 border-t space-y-2">
        <div className="flex items-center space-x-2">
          <input
            type="text"
            placeholder="Your name"
            value={senderName}
            onChange={(e) => setSenderName(e.target.value)}
            className="flex-grow px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            handleSendMessage();
          }}
          className="flex space-x-2"
        >
          <input
            type="text"
            placeholder="Type your message..."
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            className="flex-grow px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            type="submit"
            className="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!senderName.trim() || !newMessage.trim()}
          >
            <span>Send</span>
          </button>
        </form>
      </div>
    </div>
  );
}
